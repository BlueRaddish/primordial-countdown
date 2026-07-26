# base_enemy.gd
# Enemy with a patrol/chase state machine plus three movement patterns.
# All enemy types extend from this.
#
# THE COMBAT CONTRACT
# Every enemy hurts you through a telegraphed strike, never by standing near you:
#
#   CHASE -> WINDUP (visible tell) -> STRIKE (the hit window) -> RECOVER (your turn)
#
# That loop is the whole fight. Proximity used to be the threat — an enemy dealt
# full contact damage just by touching the player, on its own cooldown, even while
# being knocked back — so there was no safe window to attack into and trading hits
# was the only way to deal damage. Now contact is a small chip for standing inside a
# monster, a hurt enemy cannot touch you at all, and RECOVER is a real punish window.
#
# Hitting an enemy during WINDUP interrupts the strike outright and staggers it for
# longer than a normal hit. Reading the tell and answering it is the game.
#
# Behaviours (they differ in how they close and how they strike, not in the loop):
#   WALKER — patrols, chases on sight, turns at ledges. Strikes in place: a short
#            swipe you can simply back out of.
#   LUNGER — closes to a stand-off distance, telegraphs, then dashes through you.
#   HOPPER — chases in hops, jumps to reach a player above it, strikes by leaping.
class_name BaseEnemy
extends CharacterBody2D

enum State { PATROL, CHASE, WINDUP, STRIKE, RECOVER, HURT, DEAD }
enum Behavior { WALKER, LUNGER, HOPPER }

# --- Tuning ---
@export var behavior: Behavior = Behavior.WALKER
@export var max_health: float = 50.0
@export var move_speed: float = 40.0
@export var chase_speed: float = 65.0
@export var detection_range: float = 130.0
# Chip damage for occupying the same space as an enemy. Deliberately small: this is
# not how enemies are meant to hurt you, it only stops standing inside one being
# free. The strike is the real threat.
@export var contact_damage: float = 6.0
@export var contact_cooldown: float = 1.2
@export var gravity: float = 800.0
@export var max_fall_speed: float = 400.0
@export var knockback_decay: float = 400.0
@export var patrol_distance: float = 80.0

# --- Appearance ---
# Each movement pattern wears its own sprite, so the three read apart at a glance
# instead of relying on the player noticing how they move: a heavy orc that walks,
# a horned chort that lunges, a small imp that hops.
# The boss supplies its own frames, so it turns this off in boss_enemy.tscn.
@export var use_behavior_sprite: bool = true

# Same idea for the attack numbers: normal enemies take their timings from the
# profile for their pattern, while hand-tuned enemies (the boss) turn this off and
# keep whatever their scene set.
@export var use_behavior_profile: bool = true

const BEHAVIOR_SPRITE_FRAMES: Dictionary = {
	Behavior.WALKER: preload("res://resources/sprite_frames/enemy_walker.tres"),
	Behavior.LUNGER: preload("res://resources/sprite_frames/enemy_lunger.tres"),
	Behavior.HOPPER: preload("res://resources/sprite_frames/enemy_hopper.tres"),
}

# The sprites are not all the same height (orc and chort are 16x23, the imp is
# 16x16), so each needs its own offset to stand on the collider's base instead of
# floating above it or sinking into the floor.
const BEHAVIOR_SPRITE_Y: Dictionary = {
	Behavior.WALKER: -12.0,
	Behavior.LUNGER: -12.0,
	Behavior.HOPPER: -8.0,
}

# How each pattern fights. The three are meant to demand different answers:
# the walker punishes standing still, the lunger punishes standing in a line,
# the hopper punishes standing under it.
const BEHAVIOR_ATTACK_PROFILES: Dictionary = {
	# Slow, obvious, short reach. Back up one step and it whiffs entirely.
	Behavior.WALKER: {
		"range": 30.0, "windup": 0.55, "strike": 0.2, "recover": 0.6,
		"damage": 14.0, "radius": 30.0, "dash": 70.0, "rise": 0.0,
	},
	# Commits from far out and covers ground fast. Dodge sideways, not backwards.
	Behavior.LUNGER: {
		"range": 66.0, "windup": 0.5, "strike": 0.3, "recover": 0.75,
		"damage": 22.0, "radius": 30.0, "dash": 210.0, "rise": -70.0,
	},
	# Quickest tell of the three, but it arcs — so it beats backing away and loses
	# to simply moving under or past it.
	Behavior.HOPPER: {
		"range": 48.0, "windup": 0.35, "strike": 0.45, "recover": 0.45,
		"damage": 13.0, "radius": 28.0, "dash": 140.0, "rise": -190.0,
	},
}

# --- Strike tuning (set from the profile unless use_behavior_profile is off) ---
@export var lunge_range: float = 62.0   # distance at which it commits to a strike
@export var windup_time: float = 0.45   # the tell
@export var lunge_speed: float = 210.0  # movement carried into the strike
@export var lunge_time: float = 0.3     # how long the hit window stays open
@export var recover_time: float = 0.55  # the punish window afterwards
@export var strike_damage: float = 20.0
@export var strike_radius: float = 30.0
@export var strike_rise: float = -70.0

# Below this an enemy has left the arena entirely and is cleaned up. Sits under the
# DeathZone band (y=440..480) so anything that falls past the floor is caught.
const FALL_KILL_Y: float = 520.0

# --- Anti-camping ---
# A player standing on a high shelf used to be safe from walkers and lungers: both stop
# at ledges, so they would gather underneath and mill about indefinitely. Waiting out a
# wave from a perch is not a strategy, it is an exploit — and it gets easier now the
# arena has more verticality. After this long failing to close the gap, a ground chaser
# leaps instead.
@export var unreachable_patience: float = 2.5
# 330^2 / (2*800) = 68px of rise, the same as the player's intact jump. Enough for one
# shelf at a time; a higher perch simply takes several leaps.
@export var desperation_hop_force: float = -330.0

# --- Hopper tuning ---
@export var hop_force: float = -230.0
@export var hop_interval: float = 0.75
@export var hop_horizontal: float = 90.0

# --- Interrupt ---
# Landing a hit during the tell cancels the strike and staggers for this much longer
# than an ordinary hit. This is the payoff for reading an enemy instead of trading.
const INTERRUPT_STUN_MULT: float = 2.6
const HURT_STUN_TIME: float = 0.25

# --- Internal state ---
var _current_health: float
var _state: State = State.PATROL
var _patrol_direction: float = 1.0
var _patrol_origin_x: float = 0.0
var _contact_timer: float = 0.0
var _hurt_timer: float = 0.0
var _death_timer: float = 0.0
var _state_timer: float = 0.0
var _hop_timer: float = 0.0
var _unreachable_timer: float = 0.0
var _flash_timer: float = 0.0
var _lunge_dir: float = 1.0
# One connect per strike, so a dash cannot rake the player for its whole duration.
var _strike_connected: bool = false

# --- Status effects, applied by player skills (see status_effects.gd) ---
var _bleed_timer: float = 0.0
var _bleed_dps: float = 0.0
var _mire_timer: float = 0.0
var _mire_mult: float = 1.0
var _reel_timer: float = 0.0
var _reel_mult: float = 1.0

const BLEED_TINT: Color = Color(1.5, 0.55, 0.6)
const MIRE_TINT: Color = Color(0.6, 0.8, 1.5)
const REEL_TINT: Color = Color(1.5, 1.3, 0.55)

# Colour the sprite returns to once a hit flash ends. Subclasses can tint themselves
# by overriding this instead of fighting _update_flash every frame.
var _base_modulate: Color = Color.WHITE

# --- Danger sense (driven by the player's Hindbrain skill) ---
# How close an enemy has to be before an imminent strike counts as a threat worth
# lighting up. Roughly the reach of the shortest strike.
const CONTACT_TELL_RANGE: float = 30.0
const DANGER_HIGHLIGHT: Color = Color(2.4, 1.7, 0.35)

var _danger_highlight: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	_apply_behavior_sprite()
	_apply_behavior_profile()
	if _sprite:
		_base_modulate = _sprite.modulate
	_current_health = max_health
	_patrol_origin_x = global_position.x
	_patrol_direction = 1.0 if randf() < 0.5 else -1.0
	_hop_timer = randf_range(0.0, hop_interval)


# Swap in the sprite for whichever pattern this enemy was spawned as. The spawner
# assigns `behavior` before add_child(), so by the time _ready runs the value is
# final and this only ever happens once per enemy.
func _apply_behavior_sprite() -> void:
	if not use_behavior_sprite or not _sprite:
		return
	if BEHAVIOR_SPRITE_FRAMES.has(behavior):
		_sprite.sprite_frames = BEHAVIOR_SPRITE_FRAMES[behavior]
		_sprite.play(&"idle")
	if BEHAVIOR_SPRITE_Y.has(behavior):
		_sprite.position.y = BEHAVIOR_SPRITE_Y[behavior]


func _apply_behavior_profile() -> void:
	"""Take the strike numbers from this enemy's pattern. Same timing as the sprite
	swap — `behavior` is final by _ready, so this runs once."""
	if not use_behavior_profile:
		return
	if not BEHAVIOR_ATTACK_PROFILES.has(behavior):
		return
	var p: Dictionary = BEHAVIOR_ATTACK_PROFILES[behavior]
	lunge_range = p["range"]
	windup_time = p["windup"]
	lunge_time = p["strike"]
	recover_time = p["recover"]
	strike_damage = p["damage"]
	strike_radius = p["radius"]
	lunge_speed = p["dash"]
	strike_rise = p["rise"]


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		_process_dead(delta)
		return

	# The arena no longer has side walls, so an enemy knocked past the edge falls
	# forever. The DeathZone only masks the player layer, so nothing else would ever
	# clean it up — and a wave that can never be cleared is a softlocked run.
	if global_position.y > FALL_KILL_Y:
		_die()
		return

	match _state:
		State.PATROL:
			_process_patrol()
		State.CHASE:
			_process_chase(delta)
		State.WINDUP:
			_process_windup(delta)
		State.STRIKE:
			_process_strike(delta)
		State.RECOVER:
			_process_recover(delta)
		State.HURT:
			_process_hurt(delta)

	_apply_gravity(delta)
	_contact_timer -= delta
	_tick_statuses(delta)
	_update_flash(delta)

	move_and_slide()
	_update_animation()
	_check_contact_damage()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


# ---- State: PATROL ----

func _process_patrol() -> void:
	velocity.x = _patrol_direction * move_speed

	# Turn at the patrol bound, at a wall, or at the edge of the surface.
	var dist_from_origin: float = global_position.x - _patrol_origin_x
	if absf(dist_from_origin) > patrol_distance:
		_patrol_direction = -signf(dist_from_origin)
	elif is_on_wall() or (is_on_floor() and _is_ledge_ahead(_patrol_direction)):
		_patrol_direction *= -1.0

	velocity.x = _patrol_direction * move_speed

	var player: Node2D = _find_player()
	if player and global_position.distance_to(player.global_position) < detection_range:
		_state = State.CHASE


# ---- State: CHASE ----

func _process_chase(delta: float) -> void:
	var player: Node2D = _find_player()
	if not player:
		_enter_patrol()
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist > detection_range * 1.6:
		_enter_patrol()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dir: float = signf(to_player.x)
	if dir == 0.0:
		dir = _patrol_direction

	# Every pattern commits to a telegraphed strike once it is close enough. Only
	# how it *closes* differs below.
	if dist <= lunge_range and _can_begin_strike(to_player):
		_begin_windup(dir)
		return

	if _try_desperation_leap(delta, to_player, dir):
		return

	match behavior:
		Behavior.HOPPER:
			_chase_as_hopper(delta, to_player, dir)
		_:
			_chase_as_ground(dir)


func _try_desperation_leap(delta: float, to_player: Vector2, dir: float) -> bool:
	"""Ground patterns leap once they have spent long enough unable to reach a player
	standing above them. Returns true if the leap fired this frame.

	Hoppers already climb, so they are exempt — this exists to stop a perch being
	permanently safe, not to erase the difference between the patterns."""
	if behavior == Behavior.HOPPER or not is_on_floor():
		return false

	# "Cannot reach" means the player is meaningfully above AND we have either run out
	# of floor or are already standing underneath them.
	var player_above: bool = to_player.y < -24.0
	var stuck: bool = _is_ledge_ahead(dir) or absf(to_player.x) < 44.0
	if not (player_above and stuck):
		_unreachable_timer = maxf(_unreachable_timer - delta, 0.0)
		return false

	_unreachable_timer += delta
	if _unreachable_timer < unreachable_patience:
		return false

	_unreachable_timer = 0.0
	velocity.y = desperation_hop_force
	velocity.x = dir * _effective_chase_speed()
	return true


func _can_begin_strike(to_player: Vector2) -> bool:
	"""Ground patterns will not swing at a player far above or below them — without
	this they lock into windup/recover cycles at someone standing on a platform."""
	if behavior == Behavior.HOPPER:
		return true
	return absf(to_player.y) < 34.0


func _chase_as_ground(dir: float) -> void:
	# Ground chasers respect ledges: they stop at the edge rather than dropping off.
	if is_on_floor() and _is_ledge_ahead(dir):
		velocity.x = move_toward(velocity.x, 0.0, knockback_decay * 0.02)
		return
	velocity.x = dir * _effective_chase_speed()


func _effective_chase_speed() -> float:
	"""Current chase speed, after any slow a player skill has put on this enemy."""
	return chase_speed * _mire_mult


func _chase_as_hopper(delta: float, to_player: Vector2, dir: float) -> void:
	_hop_timer -= delta

	if not is_on_floor():
		# Steer a little mid-air so hops actually land on platforms.
		velocity.x = move_toward(velocity.x, dir * hop_horizontal, 200.0 * delta)
		return

	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	var player_is_above: bool = to_player.y < -12.0
	var blocked: bool = is_on_wall()
	if _hop_timer <= 0.0 or player_is_above or blocked:
		_hop_timer = hop_interval
		velocity.y = hop_force
		velocity.x = dir * hop_horizontal * _mire_mult


# ---- State: WINDUP / STRIKE / RECOVER ----

func _begin_windup(dir: float) -> void:
	_lunge_dir = dir
	_state = State.WINDUP
	_state_timer = windup_time
	_strike_connected = false
	velocity.x = 0.0


func _process_windup(delta: float) -> void:
	_state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	# Telegraph: the sprite pulses while the enemy is committed to attacking. This is
	# the window in which a hit interrupts it entirely.
	_flash_timer = 0.0
	if _sprite:
		# Steady red instead of a strobe when the accessibility option is on. The
		# telegraph still reads — it is the same colour — it just does not flicker.
		var pulse: float = 0.0 if GameState.reduce_flashing else 0.5 + 0.5 * sin(_state_timer * 28.0)
		_sprite.modulate = Color(1.0, 0.4 + pulse * 0.4, 0.4 + pulse * 0.4)
	if _state_timer <= 0.0:
		_state = State.STRIKE
		_state_timer = lunge_time
		velocity.x = _lunge_dir * lunge_speed
		if strike_rise != 0.0:
			velocity.y = strike_rise


func _process_strike(delta: float) -> void:
	_state_timer -= delta
	_try_connect_strike()
	if _state_timer <= 0.0 or is_on_wall():
		_state = State.RECOVER
		_state_timer = recover_time


func _try_connect_strike() -> void:
	"""Land the strike if the player is inside its reach. Once per strike, so a dash
	passing through cannot rake for its whole duration."""
	if _strike_connected:
		return
	var player: Node2D = _find_player()
	if not player or not player.has_method("take_damage"):
		return
	if global_position.distance_to(player.global_position) > strike_radius:
		return

	_strike_connected = true
	var dir: float = signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = _lunge_dir
	player.call("take_damage", strike_damage, Vector2(dir, -0.5).normalized())


func _process_recover(delta: float) -> void:
	_state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, knockback_decay * delta)
	if _state_timer <= 0.0:
		_state = State.CHASE


# ---- State: HURT ----

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, knockback_decay * delta)
	if _hurt_timer <= 0.0:
		_state = State.CHASE


# ---- State: DEAD ----

func _process_dead(delta: float) -> void:
	_death_timer -= delta
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	if _sprite:
		_sprite.modulate.a = clampf(_death_timer / 0.3, 0.0, 1.0)
	if _death_timer <= 0.0:
		queue_free()


# ---- Damage ----

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _state == State.DEAD:
		return

	# Interrupting a telegraphed strike is the core reward loop: the attack is
	# cancelled outright and the stagger runs far longer than a normal hit.
	var interrupted: bool = _state == State.WINDUP

	_current_health -= amount * _reel_mult
	_flash_timer = 0.2

	velocity = knockback

	if _current_health <= 0.0:
		_die()
	else:
		_state = State.HURT
		_hurt_timer = HURT_STUN_TIME * (INTERRUPT_STUN_MULT if interrupted else 1.0)
		_strike_connected = true # whatever was winding up does not get to land

	EventBus.enemy_hit.emit(self, amount, knockback)


# ---- Status effects ----
#
# Applied by player skills so that skills can combine rather than each doing exactly
# one thing. Every status is a plain timer here; the skill that applied it is gone by
# the time it matters.

func apply_bleed(dps: float, duration: float) -> void:
	"""Damage over time. Stacks by taking the stronger source, never by adding."""
	if dps <= 0.0 or duration <= 0.0:
		return
	_bleed_dps = maxf(_bleed_dps, dps)
	_bleed_timer = maxf(_bleed_timer, duration)


func apply_mire(mult: float, duration: float) -> void:
	"""Slow. mult below 1.0 is slower; the strongest slow wins."""
	if duration <= 0.0:
		return
	_mire_mult = minf(_mire_mult, clampf(mult, 0.05, 1.0))
	_mire_timer = maxf(_mire_timer, duration)


func apply_reeling(mult: float, duration: float) -> void:
	"""Vulnerability. mult above 1.0 means this enemy takes more damage."""
	if duration <= 0.0:
		return
	_reel_mult = maxf(_reel_mult, maxf(mult, 1.0))
	_reel_timer = maxf(_reel_timer, duration)


func is_bleeding() -> bool:
	return _bleed_timer > 0.0


func is_mired() -> bool:
	return _mire_timer > 0.0


func is_reeling() -> bool:
	return _reel_timer > 0.0


func _tick_statuses(delta: float) -> void:
	if _bleed_timer > 0.0:
		_bleed_timer -= delta
		var tick: float = _bleed_dps * delta
		_current_health -= tick
		# Routed through the player so bleed feeds omnivamp (Gorge, Rend) the same
		# way a swing does — the whole point of layering statuses onto skills.
		var player: Node2D = _find_player()
		if player and player.has_method("report_damage_dealt"):
			player.call("report_damage_dealt", tick)
		if _bleed_timer <= 0.0:
			_bleed_dps = 0.0
		if _current_health <= 0.0 and _state != State.DEAD:
			_die()
			return

	if _mire_timer > 0.0:
		_mire_timer -= delta
		if _mire_timer <= 0.0:
			_mire_mult = 1.0

	if _reel_timer > 0.0:
		_reel_timer -= delta
		if _reel_timer <= 0.0:
			_reel_mult = 1.0


func _status_tint() -> Color:
	"""Whichever status is most worth knowing about, or the base colour if none.
	Reeling wins because it is the one the player can act on right now."""
	if _reel_timer > 0.0:
		return REEL_TINT
	if _bleed_timer > 0.0:
		return BLEED_TINT
	if _mire_timer > 0.0:
		return MIRE_TINT
	return _base_modulate


# ---- Danger sense ----

func is_telegraphing() -> bool:
	"""True when this enemy is committed to hurting the player in the next moment.

	Windup and strike are the honest answer now that every pattern telegraphs. The
	proximity case is kept for the moment just before a windup begins, so the sense
	still warns you about something walking into range rather than only about an
	attack already underway."""
	if _state == State.DEAD:
		return false
	if _state == State.WINDUP or _state == State.STRIKE:
		return true
	if _state == State.HURT or _state == State.RECOVER:
		return false
	var player: Node2D = _find_player()
	if not player:
		return false
	return global_position.distance_to(player.global_position) < CONTACT_TELL_RANGE


func set_danger_highlight(on: bool) -> void:
	"""Mark this enemy as an imminent threat. _update_flash paints it; a hit flash
	still wins, since taking damage should always read first."""
	_danger_highlight = on


func get_health_fraction() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(_current_health / max_health, 0.0, 1.0)


func _die() -> void:
	_state = State.DEAD
	_death_timer = 0.4
	velocity.x = 0.0
	# Disable all collision.
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(3, false)
	EventBus.enemy_died.emit(self)


# ---- Contact damage ----

func _check_contact_damage() -> void:
	"""Chip damage for sharing space with a monster — not the main threat.

	Staggered and recovering enemies deal none at all: those states are the player's
	window to attack, and letting a knocked-back enemy still hurt them on the way out
	is exactly what made every exchange a trade."""
	if _state == State.DEAD or _contact_timer > 0.0:
		return
	if _state == State.HURT or _state == State.RECOVER:
		return

	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if not collision:
			continue
		var collider: Object = collision.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			var collider_node: Node2D = collider as Node2D
			var dir: float = signf(collider_node.global_position.x - global_position.x)
			if dir == 0.0:
				dir = 1.0
			collider.call("take_damage", contact_damage, Vector2(dir, -0.5).normalized())
			_contact_timer = contact_cooldown
			break


# ---- Helpers ----

func _enter_patrol() -> void:
	_state = State.PATROL
	_patrol_origin_x = global_position.x


func _is_ledge_ahead(dir: float) -> bool:
	"""True if there is no ground just past the enemy's feet in the given direction."""
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(dir * 12.0, -4.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, 26.0)
	)
	query.collision_mask = 4 # terrain
	query.exclude = [self]
	return space.intersect_ray(query).is_empty()


func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _update_flash(delta: float) -> void:
	if _state == State.WINDUP:
		return # Windup owns the modulate while telegraphing.
	if not _sprite:
		return
	if _flash_timer > 0.0:
		_flash_timer -= delta
		var strobe: bool = not GameState.reduce_flashing and fmod(_flash_timer, 0.1) <= 0.05
		_sprite.modulate = _status_tint() if strobe else Color(2.0, 0.5, 0.5)
	elif _danger_highlight:
		_sprite.modulate = DANGER_HIGHLIGHT
	else:
		_sprite.modulate = _status_tint()


func _update_animation() -> void:
	if not _sprite:
		return

	if velocity.x > 0.1:
		_sprite.flip_h = false
	elif velocity.x < -0.1:
		_sprite.flip_h = true

	if _state == State.DEAD:
		_sprite.play("idle") # No special death anim yet.
	elif absf(velocity.x) > 5.0:
		_sprite.play("walk")
	else:
		_sprite.play("idle")
