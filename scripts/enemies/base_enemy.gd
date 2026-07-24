# base_enemy.gd
# Enemy with a patrol/chase state machine plus three movement patterns.
# All enemy types extend from this.
#
# Behaviours:
#   WALKER — patrols, chases on sight, turns at ledges and walls.
#   LUNGER — closes to a stand-off distance, telegraphs, then lunges hard.
#   HOPPER — chases in hops and will jump to reach a player standing above it,
#            so it can actually use the arena's platforms.
class_name BaseEnemy
extends CharacterBody2D

enum State { PATROL, CHASE, WINDUP, LUNGE, RECOVER, HURT, DEAD }
enum Behavior { WALKER, LUNGER, HOPPER }

# --- Tuning ---
@export var behavior: Behavior = Behavior.WALKER
@export var max_health: float = 50.0
@export var move_speed: float = 40.0
@export var chase_speed: float = 65.0
@export var detection_range: float = 130.0
@export var contact_damage: float = 15.0
@export var contact_cooldown: float = 0.8
@export var gravity: float = 800.0
@export var max_fall_speed: float = 400.0
@export var knockback_decay: float = 400.0
@export var patrol_distance: float = 80.0

# --- Lunger tuning ---
@export var lunge_range: float = 62.0
@export var windup_time: float = 0.45
@export var lunge_speed: float = 210.0
@export var lunge_time: float = 0.3
@export var recover_time: float = 0.55

# --- Hopper tuning ---
@export var hop_force: float = -230.0
@export var hop_interval: float = 0.75
@export var hop_horizontal: float = 90.0

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
var _flash_timer: float = 0.0
var _lunge_dir: float = 1.0

# Colour the sprite returns to once a hit flash ends. Subclasses can tint themselves
# by overriding this instead of fighting _update_flash every frame.
var _base_modulate: Color = Color.WHITE

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	if _sprite:
		_base_modulate = _sprite.modulate
	_current_health = max_health
	_patrol_origin_x = global_position.x
	_patrol_direction = 1.0 if randf() < 0.5 else -1.0
	_hop_timer = randf_range(0.0, hop_interval)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		_process_dead(delta)
		return

	match _state:
		State.PATROL:
			_process_patrol()
		State.CHASE:
			_process_chase(delta)
		State.WINDUP:
			_process_windup(delta)
		State.LUNGE:
			_process_lunge(delta)
		State.RECOVER:
			_process_recover(delta)
		State.HURT:
			_process_hurt(delta)

	_apply_gravity(delta)
	_contact_timer -= delta
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

	match behavior:
		Behavior.LUNGER:
			_chase_as_lunger(dist, dir)
		Behavior.HOPPER:
			_chase_as_hopper(delta, to_player, dir)
		_:
			_chase_as_walker(dir)


func _chase_as_walker(dir: float) -> void:
	# Walkers still respect ledges: they stop at the edge rather than dropping off.
	if is_on_floor() and _is_ledge_ahead(dir):
		velocity.x = move_toward(velocity.x, 0.0, knockback_decay * 0.02)
		return
	velocity.x = dir * _effective_chase_speed()


func _chase_as_lunger(dist: float, dir: float) -> void:
	if dist <= lunge_range:
		_lunge_dir = dir
		_state = State.WINDUP
		_state_timer = windup_time
		velocity.x = 0.0
		return
	if is_on_floor() and _is_ledge_ahead(dir):
		velocity.x = 0.0
		return
	velocity.x = dir * _effective_chase_speed()


func _effective_chase_speed() -> float:
	"""Chase speed after the player's speech-driven intimidation aura.
	A player with an intact voice keeps enemies at bay; as speech degrades the
	aura shrinks and weakens, and at full loss it is gone entirely."""
	var player: Node2D = _find_player()
	if player and player.has_method("get_intimidation_factor"):
		return chase_speed * (player.call("get_intimidation_factor", global_position) as float)
	return chase_speed


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
		velocity.x = dir * hop_horizontal * (_effective_chase_speed() / maxf(chase_speed, 0.01))


# ---- State: WINDUP / LUNGE / RECOVER (lunger pattern) ----

func _process_windup(delta: float) -> void:
	_state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	# Telegraph: the sprite pulses while the enemy is committed to attacking.
	_flash_timer = 0.0
	var pulse: float = 0.5 + 0.5 * sin(_state_timer * 28.0)
	_sprite.modulate = Color(1.0, 0.4 + pulse * 0.4, 0.4 + pulse * 0.4)
	if _state_timer <= 0.0:
		_state = State.LUNGE
		_state_timer = lunge_time
		velocity.x = _lunge_dir * lunge_speed
		velocity.y = -70.0


func _process_lunge(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0 or is_on_wall():
		_state = State.RECOVER
		_state_timer = recover_time


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

	_current_health -= amount
	_flash_timer = 0.2

	velocity = knockback

	if _current_health <= 0.0:
		_die()
	else:
		_state = State.HURT
		_hurt_timer = 0.25

	EventBus.enemy_hit.emit(self, amount, knockback)


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
	if _state == State.DEAD or _contact_timer > 0.0:
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
			# A lunge connecting hits noticeably harder than a bump.
			var damage: float = contact_damage
			if _state == State.LUNGE:
				damage *= 1.5
			collider.call("take_damage", damage, Vector2(dir, -0.5).normalized())
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
	if _flash_timer > 0.0:
		_flash_timer -= delta
		_sprite.modulate = Color(2.0, 0.5, 0.5) if fmod(_flash_timer, 0.1) > 0.05 else _base_modulate
	else:
		_sprite.modulate = _base_modulate


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
