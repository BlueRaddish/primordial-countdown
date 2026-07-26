# boss_enemy.gd
# Stage boss. PLANNING1 section 7: one boss per stage.
#
# It fights on BaseEnemy's telegraph contract (windup -> strike -> recover) like
# everything else, and adds two things on top: a ground slam, and phases.
#
# PHASES
# The fight escalates at health thresholds rather than being one flat pattern for
# 420 health — a boss that never changes is just a walker with a big number. Each
# phase shortens its tells and adds to the slam:
#
#   Phase 1 (100–66%)  ground slam on a slow cycle.
#   Phase 2  (66–33%)  faster, and every slam throws a delayed outer shockwave.
#   Phase 3   (33–0%)  faster again, and the slam comes twice in a row.
#
# DAMAGE ORDER matters and is deliberate: the slam (38) hurts more than the strike
# (24), which hurts more than a bump (8). The attack you are given the most warning
# about is the one that punishes hardest for eating it. It used to be inverted — the
# slam was the weakest of the three — which quietly taught the player to ignore the
# one attack the fight actually telegraphs.
#
# TUNING THE FIRST BOSS (it lands on wave 3, and it was unwinnable)
# What a player actually brings to it: 100 HP, intact skin (×0.8 damage taken), a
# 25-damage swing on a 0.35s cooldown, and — this early — usually zero or one skill.
#
#   before:  420 HP = 17 swings to kill.  Slam 58 ×0.8 = 46 taken, so THREE slams
#            killed you, against a boss that slams every 4.5s. You needed a near
#            perfect ~25s to win with no dodge tool at all.
#   after:   260 HP = 11 swings.  Slam 38 ×0.8 = 30 taken (4 slams), strike 24 ×0.8
#            = 19 (6 strikes), bump 8 ×0.8 = 6. Roughly six mistakes of headroom,
#            and the dash now exists to avoid them.
#
# Later bosses are NOT this soft: wave_spawner scales each successive boss up, so
# this is the difficulty floor rather than the whole curve.
class_name BossEnemy
extends BaseEnemy

@export var slam_interval: float = 4.5
@export var slam_windup: float = 0.7
@export var slam_radius: float = 84.0
@export var slam_damage: float = 38.0
@export var slam_rise: float = -300.0
# The slam also throws you, so being caught costs position as well as health.
@export var slam_knockback: float = 1.6

# --- Shockwave (phase 2+) ---
# A second, wider ring that lands shortly after the slam. Standing just outside the
# slam is no longer automatically safe — you have to keep moving out.
@export var shockwave_delay: float = 0.45
@export var shockwave_radius_mult: float = 1.8
@export var shockwave_damage: float = 16.0

# Health fractions at which the next phase begins.
const PHASE_THRESHOLDS: Array[float] = [0.66, 0.33]
# The boss darkens and reddens as it escalates, so the phase is legible without UI.
const PHASE_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.25, 0.85, 0.8),
	Color(1.5, 0.6, 0.55),
]

var _slam_timer: float = 0.0
var _slam_windup_timer: float = 0.0
var _slam_falling: bool = false
var _shockwave_timer: float = 0.0
var _shockwave_origin: Vector2 = Vector2.ZERO
# Slams still owed in the current burst; phase 3 queues two.
var _slams_queued: int = 0

var _phase: int = 0

# Phase scaling is applied to these rather than to the live values, so escalation
# never compounds on itself across repeated threshold crossings.
var _base_slam_interval: float = 0.0
var _base_slam_windup: float = 0.0
var _base_chase_speed: float = 0.0
var _base_windup_time: float = 0.0


func _ready() -> void:
	super()
	_base_slam_interval = slam_interval
	_base_slam_windup = slam_windup
	_base_chase_speed = chase_speed
	_base_windup_time = windup_time
	_slam_timer = slam_interval
	EventBus.boss_spawned.emit(self, max_health)


func _physics_process(delta: float) -> void:
	super(delta)
	if _state == State.DEAD:
		return
	_update_phase()
	_process_shockwave(delta)
	_process_slam(delta)


# ---- Phases ----

func _update_phase() -> void:
	var frac: float = get_health_fraction()
	var target: int = 0
	for i: int in range(PHASE_THRESHOLDS.size()):
		if frac <= PHASE_THRESHOLDS[i]:
			target = i + 1
	if target != _phase:
		_phase = target
		_enter_phase()


func _enter_phase() -> void:
	"""Tighten every timing and re-tint. Everything scales off the captured base
	values, so this is safe to run more than once."""
	slam_interval = _base_slam_interval * pow(0.68, float(_phase))
	slam_windup = _base_slam_windup * pow(0.82, float(_phase))
	windup_time = _base_windup_time * pow(0.85, float(_phase))
	chase_speed = _base_chase_speed * (1.0 + 0.18 * float(_phase))

	if _phase < PHASE_TINTS.size():
		_base_modulate = PHASE_TINTS[_phase]

	# A wide flash on the transition so the escalation reads as a moment.
	if _phase > 0:
		var tint: Color = PHASE_TINTS[mini(_phase, PHASE_TINTS.size() - 1)]
		var flare: Node2D = Vfx.sprite(get_parent(), global_position, Vfx.TEX_FLARE)
		if flare:
			flare.set("color", tint)
			flare.set("start_size", slam_radius * 0.6)
			flare.set("end_size", slam_radius * 3.0)
			flare.set("lifetime", 0.6)
		var shock: Node2D = Vfx.sprite(get_parent(), global_position, Vfx.TEX_MAGIC_RING)
		if shock:
			shock.set("color", tint)
			shock.set("start_size", slam_radius * 0.3)
			shock.set("end_size", slam_radius * 2.6)
			shock.set("lifetime", 0.5)


# ---- Slam ----

func _process_slam(delta: float) -> void:
	# Wind up in place, leap, then slam on landing.
	if _slam_windup_timer > 0.0:
		_slam_windup_timer -= delta
		velocity.x = 0.0
		if _sprite:
			var pulse: float = (
				0.0 if GameState.reduce_flashing
				else 0.5 + 0.5 * sin(_slam_windup_timer * 30.0)
			)
			_sprite.modulate = Color(1.0, 0.35 + pulse * 0.5, 0.2)
		if _slam_windup_timer <= 0.0:
			velocity.y = slam_rise
			_slam_falling = true
		return


	if _slam_falling:
		if is_on_floor() and velocity.y >= 0.0:
			_slam_falling = false
			_do_slam()
			# Phase 3 follows straight through into a second slam.
			_slams_queued -= 1
			if _slams_queued > 0:
				_slam_windup_timer = slam_windup * 0.6
		return

	# Only wind up when the player is actually in range to be threatened.
	_slam_timer -= delta
	if _slam_timer > 0.0:
		return

	var player: Node2D = _find_player()
	if not player:
		return
	if global_position.distance_to(player.global_position) > slam_radius * 1.6:
		return

	_slam_timer = slam_interval
	_slam_windup_timer = slam_windup
	_slams_queued = 2 if _phase >= 2 else 1
	# The slam is the fight's signature attack and its hardest hit, so it gets a
	# warning ring at the true blast radius — dodging it becomes a spatial decision
	# rather than a guess about how far "near the boss" reaches.
	Vfx.telegraph(get_parent(), self, slam_radius, slam_windup)


func _do_slam() -> void:
	var origin: Vector2 = global_position
	# Scorch, shock ring and thrown debris, over the true blast radius drawn solid.
	var hb: Node2D = Vfx.hitbox(get_parent(), origin)
	if hb:
		hb.set("color", Color("c0392b"))
		hb.set("radius", slam_radius)
		hb.set("lifetime", 0.28)
	Vfx.slam(get_parent(), origin, slam_radius, Color("ff7a4a"))
	_hit_player_in_radius(origin, slam_radius, slam_damage, slam_knockback)

	# From phase 2 the slam is followed by a wider, weaker ring.
	if _phase >= 1:
		_shockwave_origin = origin
		_shockwave_timer = shockwave_delay


func _process_shockwave(delta: float) -> void:
	if _shockwave_timer <= 0.0:
		return
	_shockwave_timer -= delta
	if _shockwave_timer > 0.0:
		return
	var radius: float = slam_radius * shockwave_radius_mult
	var hb: Node2D = Vfx.hitbox(get_parent(), _shockwave_origin)
	if hb:
		hb.set("color", Color("e67e22"))
		hb.set("radius", radius)
		hb.set("lifetime", 0.26)
	var wave: Node2D = Vfx.sprite(get_parent(), _shockwave_origin, Vfx.TEX_MAGIC_RING)
	if wave:
		wave.set("color", Color("e67e22"))
		wave.set("start_size", radius * 0.5)
		wave.set("end_size", radius * 2.2)
		wave.set("lifetime", 0.38)
	_hit_player_in_radius(_shockwave_origin, radius, shockwave_damage, 1.2)


# ---- Shared helpers ----


func _hit_player_in_radius(
	origin: Vector2, radius: float, damage: float, knockback: float
) -> void:
	var player: Node2D = _find_player()
	if not player or not player.has_method("take_damage"):
		return
	if origin.distance_to(player.global_position) > radius:
		return
	var dir: float = signf(player.global_position.x - origin.x)
	if dir == 0.0:
		dir = 1.0
	# The player scales knockback by the length of this vector, so a longer-than-unit
	# vector is how these throw harder than an ordinary hit.
	player.call("take_damage", damage, Vector2(dir, -0.7).normalized() * knockback)


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	# Bosses shrug off knockback rather than being juggled across the arena.
	super(amount, knockback * 0.25)
	if _state != State.DEAD:
		EventBus.boss_health_changed.emit(get_health_fraction() * max_health, max_health)


func _die() -> void:
	super()
	EventBus.boss_defeated.emit()
