# player.gd
# Player controller — side-view platformer movement + 360° mouse-aimed AoE melee combat.
# Stats are rebuilt from TraitManager on every trait change via recalculate_from_traits().
extends CharacterBody2D

# Every visual effect goes through this. Preloaded rather than referenced by
# class_name so headless runs do not depend on the editor having rescanned.
const Vfx := preload("res://scripts/vfx/vfx.gd")

# --- Base constants (never change) ---
const BASE_MOVE_SPEED: float = 120.0
const BASE_ACCELERATION: float = 900.0
# Peak rise = JUMP_FORCE^2 / (2 * gravity) = 330^2 / 1600 = 68 px.
# The arena's optional high routes are built against that number.
const BASE_JUMP_FORCE: float = -330.0
const BASE_ATTACK_DAMAGE: float = 25.0
const BASE_MELEE_RANGE: float = 24.0 # Offset of hitbox center from player
const BASE_MELEE_LENGTH: float = 40.0 # Hitbox length along the aim direction
# Coyote time is rebuilt from this every recalculate, because an evolved Tail adds
# to it and the rebuild has to start from a clean base rather than compounding.
const BASE_COYOTE_TIME: float = 0.08
# How long a skill impulse owns locomotion. AbilityManager reads this so a
# dash-attack's travelling hitbox lasts exactly as long as the movement does.
const IMPULSE_TIME: float = 0.25

# --- Live values (rebuilt from traits) ---
@export var move_speed: float = 120.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var air_friction: float = 400.0

# --- Jump tuning ---
@export var jump_force: float = -330.0
@export var gravity: float = 800.0
@export var fall_gravity_mult: float = 1.5
@export var max_fall_speed: float = 400.0
@export var coyote_time: float = 0.08
@export var jump_buffer_time: float = 0.1

# Air acceleration as a fraction of ground acceleration. At 1.0 the air steered exactly
# like the ground, which makes a jump feel like a hover — you could rewrite the whole
# arc after committing to it. Below 1.0 the jump becomes a decision you live with.
# Multiplied by air_control_mult, so a Tail still buys back real authority on top.
@export var air_accel_ratio: float = 0.75

# Apex hang. Gravity eases off while vertical speed is near zero, so the top of a jump
# lingers instead of snapping over. This is most of what makes a jump feel "floaty at
# the top and heavy on the way down" rather than parabolic and lifeless.
@export var apex_speed_threshold: float = 55.0
@export var apex_gravity_mult: float = 0.5

# How long the player ignores the shelf it just dropped through. Long enough to clear
# the collider and its margin, short enough that you cannot fall through the next one.
@export var drop_through_time: float = 0.25

# Inputs are remembered this long while something else owns the character — an attack
# animation, a knockback, a dash cooldown — and fire the moment it is legal. Without
# this, any press during those windows is silently eaten and reads as the game
# ignoring you.
@export var dash_buffer_time: float = 0.15
@export var skill_buffer_time: float = 0.2

# Squash and stretch. Purely cosmetic, and deliberately quick: it should register as
# weight, not as a cartoon.
@export var squash_recovery: float = 9.0
@export var land_squash_speed: float = 140.0
# Mid-air jumps available after leaving the ground. Rebuilt from the legs trait.
@export var max_air_jumps: int = 1
@export var air_jump_force_mult: float = 0.9

# --- Combat tuning ---
@export var max_health: float = 100.0
@export var attack_damage: float = 25.0
@export var attack_duration: float = 0.2
@export var attack_cooldown: float = 0.35
@export var knockback_force: float = 220.0
@export var knockback_up: float = -80.0
@export var invincibility_duration: float = 0.6
@export var hit_knockback_force: float = 150.0

# --- Dash / roll ---
# The game's baseline evade, and the reason the telegraph contract is fair: every
# enemy commits to a windup before it can hurt you, so there has to be one answer
# that always works and never depends on which traits you still have.
#
# Purely horizontal, toward whichever side the cursor is on. It grants i-frames for
# its whole duration, so it beats a lunge, a slam and a shockwave alike. Free — like
# Pounce, it is movement rather than a skill, and charging years for the only
# universal defence would tax the player for being attacked.
@export var dash_speed: float = 340.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.85
# Degraded legs make it a scramble rather than a roll: shorter, but never removed.
@export var dash_legs_partial_mult: float = 0.8
@export var dash_legs_lost_mult: float = 0.55

# --- Aerial skill hang ---
# A brief float after firing a skill in mid-air. Skills already refresh the jump up
# there, but the moment you land one you were immediately back at full falling speed
# with no time to read where the chain had put you — so aerial play was committing
# blind. This hands back a beat to look, aim and choose the next move, which is what
# makes chaining feel deliberate rather than frantic.
@export var air_skill_hang_time: float = 0.18
@export var air_skill_hang_gravity_mult: float = 0.22
@export var melee_aoe_color: Color = Color("4ecdc4")

# --- Capability gates (set by TraitManager) ---
var movement_enabled: bool = true
var _can_jump: bool = true
var arms_blocked: bool = false

# --- Live trait-derived stats (rebuilt by recalculate_from_traits) ---
var health_regen: float = 1.5 # Gut: health per second
var attack_cooldown_mult: float = 1.0 # Lungs: swing recovery
var passive_damage_taken_mult: float = 1.0 # Skin (and evolved Hide): flat protection
var vision_mod: float = 1.0 # Eyes: world brightness

# --- Evolved trait state (set by recalculate_from_traits from EvolvedTraitManager) ---
var has_wings: bool = false # Wings: glide + an extra mid-air flap
var glide_gravity_mult: float = 0.35 # How much gravity wings cancel while gliding
var has_tail: bool = false # Tail: mid-air steering that survives losing the legs
var air_control_mult: float = 1.0 # Tail: mid-air steering authority
var knockback_resist: float = 0.0 # Plates: fraction of incoming knockback shrugged off
var attack_bleed_dps: float = 0.0 # Claws: ordinary swings leave a bleed
var attack_bleed_time: float = 0.0

# --- Internal state ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _skill_buffer_timer: float = 0.0
var _skill_buffer_slot: int = -1
var _drop_through_timer: float = 0.0
var _dropped_platform: Node = null
# Fall speed carried into the moment of landing, sampled before move_and_slide zeroes
# it. Drives how hard the landing squashes and how much dust it kicks up.
var _impact_speed: float = 0.0
var _was_airborne: bool = false
var _air_jumps_left: int = 0
var _was_on_floor: bool = false
var _is_dead: bool = false
var _spawn_position: Vector2 = Vector2.ZERO

# Combat state.
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _is_attacking: bool = false
# Enemies already damaged by the current swing, so a swing that stays open for
# several frames still only hits each target once.
var _hit_this_swing: Array[Node2D] = []
var _invincibility_timer: float = 0.0
var _impulse_timer: float = 0.0
# Dash state. _dash_timer > 0 means the roll is active AND untouchable.
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_dir: float = 1.0
# Counts down the float granted by an aerial skill.
var _air_hang_timer: float = 0.0
var _facing_right: bool = true
var _aim_angle: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var _slash_effect: SlashEffect = $SlashEffect
@onready var _trait_manager: TraitManager = $TraitManager
@onready var _ability_manager: AbilityManager = $AbilityManager
@onready var _status_effects: StatusEffects = $StatusEffects
@onready var _evolved_manager: Node = get_node_or_null("EvolvedTraitManager")
@onready var _body_marks: BodyMarks = get_node_or_null("BodyMarks") as BodyMarks


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	_attack_shape.disabled = true

	# The hitbox shape is resized as the arms degrade, so give this instance its
	# own copy rather than mutating a resource shared with the packed scene.
	if _attack_shape.shape:
		_attack_shape.shape = _attack_shape.shape.duplicate()

	# Stick to platforms when running across them instead of skipping off ledges.
	floor_snap_length = 6.0

	EventBus.player_died.connect(_on_player_died)
	EventBus.player_hit.connect(_on_player_hit)
	# Firing a skill in mid-air refreshes the jump (see _on_skill_used), which is
	# what makes aerial skill chains a real mobility option.
	EventBus.skill_used.connect(_on_skill_used)
	# Sync health display.
	EventBus.player_health_changed.emit(GameState.player_health, GameState.player_max_health)

	# Traits are all intact at this point, but this establishes every derived stat
	# (regen, reach, vision) from one place instead of relying on the defaults.
	call_deferred("_initial_recalculate")


func _initial_recalculate() -> void:
	if _trait_manager:
		_trait_manager.recalculate_all()


func _physics_process(delta: float) -> void:
	if _is_dead:
		_apply_gravity(delta)
		move_and_slide()
		return

	_handle_timers(delta)
	_handle_drop_through()
	# The dash owns velocity outright while it runs, so it is resolved before
	# gravity and movement rather than fighting them.
	if _handle_dash(delta):
		move_and_slide()
		_update_animation()
		_apply_squash_stretch(delta)
		_was_on_floor = is_on_floor()
		return
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement(delta)
	_handle_attack(delta)
	_handle_skill_input()
	_handle_invincibility(delta)
	_handle_regen(delta)
	_update_animation()

	# Sampled before move_and_slide, which zeroes downward velocity on contact — by
	# the time we could ask "how hard did that land?" the answer is always zero.
	_impact_speed = velocity.y
	_was_airborne = not is_on_floor()
	var speed_before: float = absf(velocity.x)

	move_and_slide()

	_check_landing()
	_check_skid(speed_before)
	_apply_squash_stretch(delta)
	_was_on_floor = is_on_floor()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event.is_action_pressed("character_screen"):
		EventBus.character_screen_toggled.emit(true)


# ---- Trait integration ----

func recalculate_from_traits(trait_mgr: TraitManager) -> void:
	"""Rebuild all live stats from current trait state.

	Every stat is rebuilt from scratch rather than nudged by deltas, so trait
	changes can be applied in any order and undone freely (the dev +/- buttons
	depend on this)."""
	# Legs: movement speed and jump height.
	var leg_mod: float = trait_mgr.get_modifier("legs")
	move_speed = BASE_MOVE_SPEED * leg_mod
	acceleration = BASE_ACCELERATION * leg_mod
	jump_force = BASE_JUMP_FORCE * trait_mgr.get_leg_jump_mod()
	max_air_jumps = trait_mgr.get_air_jumps()
	_air_jumps_left = mini(_air_jumps_left, max_air_jumps)
	coyote_time = BASE_COYOTE_TIME
	air_control_mult = 1.0
	knockback_resist = 0.0

	# Arms: damage and reach. Only a natural weapon bleeds, so this clears back to
	# nothing and the evolved pass below puts it back if claws have grown.
	attack_damage = BASE_ATTACK_DAMAGE * trait_mgr.get_arm_damage_mod()
	_apply_melee_reach(trait_mgr.get_arm_range_mod())
	attack_bleed_dps = 0.0
	attack_bleed_time = 0.0

	# Gut: passive health regen.
	health_regen = trait_mgr.get_gut_regen_rate()

	# Lungs: how fast the player recovers between swings.
	attack_cooldown_mult = trait_mgr.get_lungs_cooldown_mult()

	# Skin: passive protection. The evolved Hide overrides this with heavier armor.
	passive_damage_taken_mult = trait_mgr.get_skin_damage_taken_mult()

	# Eyes: world brightness.
	vision_mod = trait_mgr.get_eyes_vision_mod()
	_apply_vision()

	# Capability gates.
	movement_enabled = not trait_mgr.is_movement_blocked()
	_can_jump = trait_mgr.can_jump()
	arms_blocked = trait_mgr.is_arms_blocked()

	# Evolved traits layer on top of the base trait stats.
	_apply_evolved_traits()

	# Last, because it reports on the finished state of both.
	_update_body_appearance(trait_mgr)


func _apply_evolved_traits() -> void:
	"""Fold any grown evolved traits into the live stats.

	An evolved trait takes over the role of the slot it grew from, so these are
	applied last and overwrite the relevant stat rather than stacking with the trait
	they succeed. Only one evolved trait can hold a slot (EvolvedTraitManager
	enforces it), so nothing here has to reconcile two claims on the same stat."""
	has_wings = false
	has_tail = false
	if not _evolved_manager:
		return

	# --- arms slot: Wings or Claws ---
	if _evolved_manager.call("has_trait", "wings"):
		has_wings = true
		# Wings restore an extra mid-air flap even with the arms gone.
		max_air_jumps = maxi(max_air_jumps, 1)
		_air_jumps_left = mini(_air_jumps_left, max_air_jumps)
		# If the legs are also gone their jump force is zero; wings give their own
		# flap so the player can still gain height. minf keeps stronger leg jumps.
		jump_force = minf(jump_force, BASE_JUMP_FORCE * 0.75)

	# Claws hand the melee back after the arms are gone — the arm mods have already
	# zeroed damage and reach, so this replaces both outright instead of scaling them.
	var restorer: EvolvedTraitData = _evolved_manager.call("get_attack_restorer")
	if restorer:
		arms_blocked = false
		attack_damage = BASE_ATTACK_DAMAGE * restorer.attack_damage_mult
		_apply_melee_reach(restorer.attack_range_mult)
		attack_bleed_dps = restorer.attack_bleed_dps
		attack_bleed_time = restorer.attack_bleed_time

	# --- legs slot: Tail ---
	if _evolved_manager.call("has_trait", "tail"):
		has_tail = true
	air_control_mult = _evolved_manager.call("get_air_control_mult") as float
	coyote_time = BASE_COYOTE_TIME + (_evolved_manager.call("get_coyote_bonus") as float)

	# --- skin slot: Hide or Plates ---
	# Both are far tougher than skin ever was. Plates additionally anchor you.
	passive_damage_taken_mult = minf(
		passive_damage_taken_mult, _evolved_manager.call("get_damage_taken_mult") as float
	)
	knockback_resist = _evolved_manager.call("get_knockback_resist") as float

	# --- lungs slot: Gills ---
	# Breathing moves off the ruined lungs, so their swing penalty stops applying.
	var cd_override: float = _evolved_manager.call("get_attack_cooldown_override") as float
	if cd_override > 0.0:
		attack_cooldown_mult = cd_override


func _update_body_appearance(trait_mgr: TraitManager) -> void:
	"""Make the devolution visible on the body itself.

	Two channels: the sprite drains toward a bloodless grey as the traits go, and
	BodyMarks draws whatever has grown back. Until this existed the entire fantasy —
	a body coming apart and improvising — was happening only in the HUD."""
	var decay: float = _get_devolution_fraction(trait_mgr)
	if _sprite:
		var tint: Color = Color.WHITE.lerp(Color(0.58, 0.55, 0.62), decay)
		# Alpha belongs to the invincibility flicker; only the colour is ours.
		tint.a = _sprite.modulate.a
		_sprite.modulate = tint

	if not _body_marks:
		return

	var armor: Color = Color.TRANSPARENT
	var has_claws: bool = false
	var has_gills: bool = false
	if _evolved_manager:
		has_claws = _evolved_manager.call("has_trait", "claws")
		has_gills = _evolved_manager.call("has_trait", "gills")
		for id: String in ["hide", "plates"]:
			if _evolved_manager.call("has_trait", id):
				var data: EvolvedTraitData = _evolved_manager.call("get_definition", id)
				if data:
					armor = data.color

	_body_marks.set_marks(has_wings, has_tail, has_claws, has_gills, armor)


func _get_devolution_fraction(trait_mgr: TraitManager) -> float:
	"""How far gone the body is, 0.0 (all intact) to 1.0 (everything fully lost).
	Counts partial stages too, so the drain is gradual rather than stepping only on
	full losses."""
	var total: int = 0
	for trait_name: String in TraitManager.ALL_TRAITS:
		total += trait_mgr.get_trait_stage(trait_name)
	var max_total: int = TraitManager.ALL_TRAITS.size() * TraitManager.MAX_STAGE
	if max_total <= 0:
		return 0.0
	return float(total) / float(max_total)


func _melee_rect_size() -> Vector2:
	"""The AttackHitbox's live extents, read from the shape itself so the drawn box is
	the real one even after the arms degrade and shrink it."""
	if _attack_shape:
		var rect: RectangleShape2D = _attack_shape.shape as RectangleShape2D
		if rect:
			return rect.size
	return Vector2(BASE_MELEE_LENGTH, 28.0)


func _melee_offset() -> float:
	"""How far the hitbox sits from the player, again read from the live node."""
	if _attack_shape:
		return _attack_shape.position.x
	return BASE_MELEE_RANGE


func _melee_reach() -> float:
	return _melee_offset() + _melee_rect_size().x * 0.5


func _apply_melee_reach(range_mod: float) -> void:
	"""Shrink the melee hitbox toward the player as the arms degrade.

	Both the length and the offset scale, so partial arms genuinely have shorter
	reach rather than just a box sitting closer in."""
	if not _attack_shape:
		return
	var scale_factor: float = maxf(range_mod, 0.25)
	var rect: RectangleShape2D = _attack_shape.shape as RectangleShape2D
	if rect:
		rect.size.x = BASE_MELEE_LENGTH * scale_factor
	_attack_shape.position.x = BASE_MELEE_RANGE * scale_factor
	if _slash_effect:
		_slash_effect.aoe_radius = BASE_MELEE_LENGTH * scale_factor


func _apply_vision() -> void:
	"""Eyes drive world brightness through the arena's CanvasModulate."""
	var modulators: Array[Node] = get_tree().get_nodes_in_group("vision_modulate")
	for node: Node in modulators:
		var cm: CanvasModulate = node as CanvasModulate
		if cm:
			var v: float = clampf(vision_mod, 0.0, 1.0)
			cm.color = Color(v, v, minf(v + 0.06, 1.0))


func get_aim_direction() -> Vector2:
	"""Recomputed from the cursor on every call, so skills fired without attacking
	first (Pounce especially) aim where the player is actually pointing rather than
	at wherever the last swing happened to land."""
	return _refresh_aim_from_mouse()


func _refresh_aim_from_mouse() -> Vector2:
	var player_center: Vector2 = global_position + Vector2(0.0, -10.0)
	var dir_to_mouse: Vector2 = get_global_mouse_position() - player_center
	if dir_to_mouse.length_squared() > 0.001:
		_aim_dir = dir_to_mouse.normalized()
	else:
		_aim_dir = Vector2.RIGHT if _facing_right else Vector2.LEFT
	_aim_angle = _aim_dir.angle()
	return _aim_dir


# ---- Alternative movement (skill impulse) ----

func get_impulse_time() -> float:
	"""How long a skill impulse owns locomotion. AbilityManager matches its travelling
	hitbox to this, so a dash-attack damages for exactly as long as it is moving."""
	return IMPULSE_TIME


func apply_impulse(direction: Vector2, speed: float, upward_bias: float) -> void:
	"""Alternative movement hook, used when a skill takes over locomotion."""
	if _is_dead:
		return
	var dir: Vector2 = direction
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT if _facing_right else Vector2.LEFT
	velocity = dir.normalized() * speed
	velocity.y -= upward_bias
	_impulse_timer = IMPULSE_TIME
	_facing_right = dir.x >= 0.0


# ---- Damage reporting (omnivamp routes through here) ----

func report_damage_dealt(amount: float) -> void:
	if amount <= 0.0:
		return
	EventBus.player_damage_dealt.emit(amount)
	if _status_effects:
		var vamp: float = _status_effects.get_omnivamp()
		if vamp > 0.0:
			GameState.heal_player(amount * vamp)


# ---- Gravity ----

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_air_hang_timer = 0.0
		return

	# A skill fired in mid-air buys a moment of near-weightlessness to read the
	# situation. Applied before the fall multiplier so it works on the way down,
	# which is when you actually need it.
	if _air_hang_timer > 0.0:
		_air_hang_timer -= delta
		velocity.y = minf(
			velocity.y + gravity * air_skill_hang_gravity_mult * delta,
			max_fall_speed * 0.3
		)
		return

	var grav: float = gravity
	# Apex hang, applied on both sides of the arc so the top of a jump rounds off
	# instead of turning a corner. Checked before the fall multiplier so the very
	# start of the descent still counts as apex rather than immediately going heavy.
	if absf(velocity.y) < apex_speed_threshold:
		grav *= apex_gravity_mult
	if velocity.y > 0.0:
		grav *= fall_gravity_mult
		# Wings: hold jump while falling to glide — gravity is mostly cancelled and
		# the descent is capped to a slow drift. Turns a fall into a traversal tool.
		if has_wings and _impulse_timer <= 0.0 and Input.is_action_pressed("jump"):
			grav *= glide_gravity_mult
			velocity.y = minf(velocity.y + grav * delta, max_fall_speed * 0.35)
			return
	velocity.y = minf(velocity.y + grav * delta, max_fall_speed)


# ---- Jump ----

func _handle_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		# Refilled here rather than on landing, so the count is always correct even
		# if the player is pushed onto a surface without a clean landing frame.
		_air_jumps_left = max_air_jumps
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	# Dash and skills buffer the same way the jump does: the press is remembered and
	# spent as soon as it becomes legal, rather than being dropped because an attack
	# animation or a knockback happened to own the character that frame.
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time
	else:
		_dash_buffer_timer -= delta

	if Input.is_action_just_pressed("skill_q"):
		_buffer_skill(0)
	elif Input.is_action_just_pressed("skill_e"):
		_buffer_skill(1)
	elif Input.is_action_just_pressed("skill_r"):
		_buffer_skill(2)
	else:
		_skill_buffer_timer -= delta
		if _skill_buffer_timer <= 0.0:
			_skill_buffer_slot = -1

	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			_end_drop_through()

	if _impulse_timer > 0.0:
		_impulse_timer -= delta


func _buffer_skill(slot: int) -> void:
	_skill_buffer_slot = slot
	_skill_buffer_timer = skill_buffer_time


func _handle_jump() -> void:
	# Wings keep the jump/flap available even after the legs are fully gone.
	if not _can_jump and not has_wings:
		return

	if _jump_buffer_timer > 0.0:
		var floor_jump: bool = is_on_floor() or _coyote_timer > 0.0
		if floor_jump:
			velocity.y = jump_force
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			# Stretch on the way up, squash on the way down. The pair reads as effort
			# and then weight; either one alone just looks like a rendering glitch.
			if _sprite:
				_sprite.scale = Vector2(0.84, 1.2)
			_spawn_dust(global_position, 7.0, Color(0.82, 0.8, 0.72))
		elif _air_jumps_left > 0:
			# Mid-air jump: reset vertical velocity rather than adding to it, so a
			# double jump behaves the same whether it is used rising or falling.
			_air_jumps_left -= 1
			velocity.y = jump_force * air_jump_force_mult
			_jump_buffer_timer = 0.0
			_spawn_air_jump_puff()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.4


# ---- Dash / roll ----

func _handle_dash(delta: float) -> bool:
	"""Run the dash. Returns true while it owns movement this frame.

	Horizontal only and aimed by the cursor, not by which way you happen to face —
	so it is a deliberate direction rather than a commitment to your current facing.
	Gravity is suspended for the duration, which is what makes it reliable as an
	answer to a ground slam."""
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir * dash_speed * _dash_distance_mult()
		velocity.y = 0.0
		return true

	# Buffered rather than edge-triggered, so a dash pressed during an attack swing or
	# a knockback fires the instant the character is free instead of being swallowed.
	if _dash_buffer_timer <= 0.0:
		return false
	if _dash_cooldown_timer > 0.0 or _is_attacking:
		return false
	_dash_buffer_timer = 0.0

	# Toward the cursor's side. Dead centre falls back to current facing.
	var to_mouse: float = get_global_mouse_position().x - global_position.x
	if absf(to_mouse) < 1.0:
		_dash_dir = 1.0 if _facing_right else -1.0
	else:
		_dash_dir = signf(to_mouse)
	_facing_right = _dash_dir > 0.0

	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	velocity.y = 0.0
	_spawn_dash_trail()
	# Kicked up behind the dash, so the burst has a direction you can read.
	_spawn_dust(global_position - Vector2(_dash_dir * 6.0, 0.0), 9.0, Color(0.8, 0.86, 0.95))
	if _sprite:
		_sprite.scale = Vector2(1.25, 0.8)
	return true


func _dash_distance_mult() -> float:
	"""Degraded legs shorten the roll but never take it away — losing your evade
	entirely would make late-run devolution unplayable rather than harder."""
	if not _trait_manager:
		return 1.0
	match _trait_manager.get_trait_stage("legs"):
		TraitManager.STAGE_PARTIAL:
			return dash_legs_partial_mult
		TraitManager.STAGE_LOST:
			return dash_legs_lost_mult
	return 1.0


func is_dashing() -> bool:
	return _dash_timer > 0.0


func get_dash_cooldown_fraction() -> float:
	"""1.0 just used, 0.0 ready — for the HUD."""
	if dash_cooldown <= 0.0:
		return 0.0
	return _dash_cooldown_timer / dash_cooldown


func _spawn_dash_trail() -> void:
	# A streak along the roll rather than a circle: the dash is directional, and a
	# symmetric puff said nothing about which way you had committed.
	Vfx.dash_trail(
		get_parent(),
		global_position + Vector2(0.0, -10.0),
		Vector2(_dash_dir, 0.0),
		Color(0.75, 0.9, 1.0)
	)


# ---- Drop-through ----

func _handle_drop_through() -> void:
	"""Press down on a one-way shelf to fall through it.

	Works by adding a collision exception against the specific body underfoot rather
	than by dropping the terrain mask, so the ground and the walls stay solid — you
	can only ever fall through the thing you were standing on."""
	if not Input.is_action_just_pressed("move_down"):
		return
	if not is_on_floor() or _drop_through_timer > 0.0:
		return
	if not movement_enabled:
		return

	var platform: Node = _floor_platform()
	if platform == null:
		return

	_dropped_platform = platform
	add_collision_exception_with(platform as CollisionObject2D)
	_drop_through_timer = drop_through_time
	# A nudge downward so the player separates from the surface immediately instead of
	# waiting for gravity to build up past the one-way margin.
	global_position.y += 2.0
	velocity.y = maxf(velocity.y, 40.0)


func _floor_platform() -> Node:
	"""The one-way platform currently underfoot, or null if standing on solid ground."""
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("one_way_platform"):
			return collider as Node
	return null


func _end_drop_through() -> void:
	if _dropped_platform != null and is_instance_valid(_dropped_platform):
		remove_collision_exception_with(_dropped_platform as CollisionObject2D)
	_dropped_platform = null


# ---- Landing, skid, squash & stretch ----

func _check_landing() -> void:
	if not (_was_airborne and is_on_floor()):
		return
	if _impact_speed < land_squash_speed:
		return
	# Heavier landings squash harder and throw more dust, up to a cap — otherwise a
	# terminal-velocity drop looks identical to stepping off a kerb.
	var t: float = clampf(_impact_speed / max_fall_speed, 0.0, 1.0)
	if _sprite:
		_sprite.scale = Vector2(1.0 + 0.28 * t, 1.0 - 0.26 * t)
	_spawn_dust(global_position, 9.0 + 9.0 * t, Color(0.85, 0.82, 0.72))


func _check_skid(speed_before: float) -> void:
	"""Dust for a sudden horizontal stop — running into a wall, or braking hard."""
	if not is_on_floor() or speed_before < move_speed * 0.7:
		return
	if absf(velocity.x) > speed_before * 0.45:
		return  # still moving; not a stop
	_spawn_dust(
		global_position + Vector2(-signf(speed_before) * 4.0, 0.0),
		8.0,
		Color(0.8, 0.78, 0.7)
	)


func _apply_squash_stretch(delta: float) -> void:
	"""Ease the sprite back to its true proportions. Everything else here only ever
	pushes it away from 1:1; this is the only thing that returns it."""
	if not _sprite:
		return
	if _sprite.scale.is_equal_approx(Vector2.ONE):
		return
	_sprite.scale = _sprite.scale.lerp(Vector2.ONE, clampf(squash_recovery * delta, 0.0, 1.0))


func _spawn_dust(at: Vector2, radius: float, _colour: Color) -> void:
	# Radius is reused as "how hard" — a heavier landing throws more.
	Vfx.dust(get_parent(), at, clampf(radius / 10.0, 0.4, 2.0))


func _spawn_air_jump_puff() -> void:
	"""A downward kick of air under the feet, so the second jump reads as pushing off
	something rather than as a generic sparkle."""
	var ring: Node2D = Vfx.sprite(get_parent(), global_position, Vfx.TEX_TWIRL)
	if ring:
		ring.set("color", Color(0.8, 0.9, 1.0))
		ring.set("start_size", 8.0)
		ring.set("end_size", 30.0)
		ring.set("lifetime", 0.26)
		ring.set("start_alpha", 0.7)
	Vfx.dust(get_parent(), global_position, 0.5)


# ---- Horizontal movement ----

func _handle_horizontal_movement(delta: float) -> void:
	# A skill impulse owns velocity for its brief window.
	if _impulse_timer > 0.0:
		return

	if not movement_enabled:
		# A tail is not a leg. Once it has grown, mid-air steering survives losing
		# the legs entirely — which is the whole reason to grow one.
		if has_tail and not is_on_floor():
			var tail_input: float = Input.get_axis("move_left", "move_right")
			if tail_input != 0.0:
				velocity.x = move_toward(
					velocity.x,
					tail_input * BASE_MOVE_SPEED * 0.6,
					BASE_ACCELERATION * air_control_mult * delta
				)
				_facing_right = tail_input > 0.0
				return
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	if _is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, friction * 0.5 * delta)
		return

	var input_dir: float = Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		# Air control is a separate authority from ground acceleration, so a Tail can
		# make you far more precise airborne without changing how you run.
		var accel: float = acceleration
		if not is_on_floor():
			accel *= air_control_mult * air_accel_ratio
		velocity.x = move_toward(velocity.x, input_dir * move_speed, accel * delta)
		_facing_right = input_dir > 0.0
	else:
		var fric: float = friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


# ---- 360° Mouse-Aimed AoE Attack ----

func _handle_attack(delta: float) -> void:
	_attack_cooldown_timer -= delta

	if _is_attacking:
		_attack_timer -= delta
		# Damage is checked every frame the swing is open, not once when it ends.
		# Landing it only on the final frame meant you had to stay inside an enemy for
		# the whole swing to hit it at all — which is most of why trading damage felt
		# compulsory. Each enemy is still only hit once per swing.
		_apply_attack_damage()
		if _attack_timer <= 0.0:
			_finish_attack()
		return

	if arms_blocked:
		return

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	_is_attacking = true
	_attack_timer = attack_duration
	_hit_this_swing.clear()

	# Throat sets the baseline swing recovery; a buff (Second Wind) can cut it back down.
	var cd_mult: float = attack_cooldown_mult
	if _status_effects:
		cd_mult *= _status_effects.get_attack_cooldown_mult()
	_attack_cooldown_timer = attack_cooldown * cd_mult

	_refresh_aim_from_mouse()
	_facing_right = _aim_dir.x >= 0.0

	# Rotate AttackHitbox toward mouse angle.
	_attack_hitbox.rotation = _aim_angle
	_attack_shape.disabled = false

	# Show AoE fill for the melee attack.
	if _slash_effect:
		_slash_effect.play(attack_duration, _aim_angle)

	# The true melee hitbox, drawn solid, with the swing arc over it — so the reach
	# you see is the reach that actually connects.
	var swing_center: Vector2 = global_position + Vector2(0.0, -10.0) + _aim_dir * _melee_offset()
	var box: Node2D = Vfx.hitbox(get_parent(), swing_center)
	if box:
		box.set("shape", 1) # VfxHitbox.Shape.RECT
		box.set("color", melee_aoe_color)
		box.set("rect_size", _melee_rect_size())
		box.set("angle", _aim_angle)
		box.set("lifetime", attack_duration + 0.06)
	# Rides the player so the swing stays attached to the body that threw it.
	Vfx.slash(
		get_parent(), swing_center, _aim_angle, _melee_reach(), melee_aoe_color, self
	)

	# This is the devolution clock's driver: every swing counts, landed or not.
	EventBus.attack_made.emit()


func _finish_attack() -> void:
	_is_attacking = false
	_attack_shape.disabled = true


func _apply_attack_damage() -> void:
	"""Damage every enemy inside the swing that this swing has not already hit.

	Called on each frame the hitbox is open. The per-swing set is what keeps a 0.2s
	window from ticking damage twelve times while still letting the hit register the
	instant an enemy enters reach."""
	var damage: float = attack_damage
	if _status_effects:
		damage *= _status_effects.get_damage_mult()

	var hit_count: int = 0
	for body: Node2D in _attack_hitbox.get_overlapping_bodies():
		if not body.is_in_group("enemies") or not body.has_method("take_damage"):
			continue
		if _hit_this_swing.has(body):
			continue
		_hit_this_swing.append(body)

		var player_center: Vector2 = global_position + Vector2(0.0, -10.0)
		var kb_dir: Vector2 = (body.global_position - player_center).normalized()
		if kb_dir == Vector2.ZERO:
			kb_dir = _aim_dir
		var kb: Vector2 = Vector2(kb_dir.x * knockback_force, knockback_up)
		body.call("take_damage", damage, kb)
		Vfx.impact(get_parent(), body.global_position + Vector2(0.0, -10.0), kb_dir, melee_aoe_color)
		if attack_bleed_dps > 0.0 and body.has_method("apply_bleed"):
			body.call("apply_bleed", attack_bleed_dps, attack_bleed_time)
			# Claws tear rather than strike, so a bleeding hit gets its own mark.
			Vfx.sprite(get_parent(), body.global_position + Vector2(0.0, -10.0), Vfx.TEX_SCRATCH)
		hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)
		report_damage_dealt(damage * float(hit_count))


# ---- Skill Input ----

func _handle_skill_input() -> void:
	"""Spend a buffered skill press once the character can act on it.

	`activate_skill` already refuses when the slot is empty or on cooldown, so the
	buffer is cleared on a genuine attempt either way — otherwise a press at an empty
	slot would keep retrying for the whole buffer window and fire later by surprise."""
	if not _ability_manager:
		return
	if _skill_buffer_slot < 0 or _skill_buffer_timer <= 0.0:
		return
	if _is_attacking or _dash_timer > 0.0:
		return  # keep it buffered; the window is short

	var slot: int = _skill_buffer_slot
	_skill_buffer_slot = -1
	_skill_buffer_timer = 0.0
	_ability_manager.activate_skill(slot)


func _on_skill_used(_skill: Resource) -> void:
	"""A skill that actually fires while airborne refreshes the jump.

	Not a double jump — the ground jump itself is handed back, so weaving a skill
	into a jump lets the player keep height and stay mobile. Refilling air jumps
	and reopening the coyote window covers both the floor-jump and air-jump paths.
	Skipped when the legs are fully gone, since there is no jump to give back."""
	if _is_dead or is_on_floor():
		return
	# The hang is granted to ANY aerial skill, including when the legs are gone and
	# there is no jump left to refresh — that case is exactly when a moment to
	# reorient matters most.
	_air_hang_timer = air_skill_hang_time
	if not _can_jump and not has_wings:
		return
	_air_jumps_left = max_air_jumps
	_coyote_timer = coyote_time


# ---- Damage / Health ----

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	# A dash is untouchable for its whole duration. This is the one defence that
	# works regardless of trait state, so it deliberately beats everything —
	# contact, strikes, the boss slam and its shockwave alike.
	if _is_dead or _invincibility_timer > 0.0 or _dash_timer > 0.0:
		return

	var incoming: float = amount
	# Skin (and the evolved Hide) is a passive layer applied before any timed buff.
	incoming *= passive_damage_taken_mult
	if _status_effects:
		incoming *= _status_effects.get_damage_taken_mult()
		if _status_effects.is_invulnerable():
			return

	GameState.damage_player(incoming, knockback_dir)


func respawn_at_start() -> void:
	"""Used by the death zone while god mode is on, so falling off is not a run ender."""
	global_position = _spawn_position
	velocity = Vector2.ZERO


func _on_player_hit(_damage: float, knockback_dir: Vector2) -> void:
	if _is_dead:
		return
	# Plates make you very hard to shift: the hit still lands, it just stops throwing
	# you across the arena. The small upward pop is kept so a hit always reads.
	velocity = knockback_dir * hit_knockback_force * (1.0 - knockback_resist)
	velocity.y = minf(velocity.y, -60.0)
	_invincibility_timer = invincibility_duration
	# Taking a hit needs to read as loudly as landing one — in red, from the direction
	# it came, so a bad trade is legible in the moment rather than only on the bar.
	Vfx.impact(
		get_parent(),
		global_position + Vector2(0.0, -10.0),
		knockback_dir.normalized(),
		Color("ff5a4a")
	)


func _on_player_died() -> void:
	_is_dead = true
	_attack_shape.disabled = true
	if _slash_effect:
		_slash_effect.stop()
	if _status_effects:
		_status_effects.clear_all()
	set_collision_layer_value(1, false)
	set_collision_mask_value(3, false)


# ---- Gut: passive regen ----

func _handle_regen(delta: float) -> void:
	if health_regen <= 0.0:
		return
	if GameState.player_health >= GameState.player_max_health:
		return
	GameState.heal_player(health_regen * delta)


# ---- Invincibility ----

func _handle_invincibility(delta: float) -> void:
	if _dash_timer > 0.0:
		# Distinct look from the hit-flicker: a steady ghost, so "I am untouchable
		# right now" reads differently from "I just got hit".
		_sprite.modulate.a = 0.5
	elif _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if GameState.reduce_flashing:
			# Steady semi-transparency rather than a strobe: still obviously
			# invincible, without the flicker.
			_sprite.modulate.a = 0.55
		else:
			_sprite.modulate.a = 0.3 if fmod(_invincibility_timer, 0.1) > 0.05 else 1.0
	else:
		_sprite.modulate.a = 1.0


# ---- Animation ----

func _update_animation() -> void:
	# Grown parts follow the body: wings beat harder airborne, the tail sways against
	# whichever way you are moving.
	if _body_marks:
		_body_marks.set_motion(_facing_right, not is_on_floor(), velocity.x)

	if not _sprite:
		return

	if _facing_right:
		_sprite.flip_h = false
	else:
		_sprite.flip_h = true

	_play_anim(_pick_animation())


# Frame size per animation, used to bottom-centre every frame on the player's feet.
# The sheets have different frame heights (48, 77, 80, 32), so a centred sprite would
# make the character sink or float whenever the animation changed.
const ANIM_FRAMES: Dictionary = {
	"idle": Vector2(38, 48),
	"walk": Vector2(66, 48),
	"jump": Vector2(61, 77),
	"attack": Vector2(96, 48),
	"jump_attack": Vector2(84, 80),
	"hurt": Vector2(48, 48),
	"crouch": Vector2(48, 48),
	"crouch_slash": Vector2(80, 32),
}


func _pick_animation() -> String:
	"""Which animation the current body can actually perform.

	This is how the form changes stay ANIMATED rather than becoming a static pose. The
	sprite sheet cannot have an arm removed from it without redrawing every frame, so
	instead the *set of animations* changes with the body: legs gone means the hero can
	no longer stand, so it uses the crouch set and keeps moving. The trait is expressed
	by which animation plays, not by editing the art."""
	var legs_lost: bool = _trait_manager != null and _trait_manager.is_lost("legs")

	if _invincibility_timer > invincibility_duration * 0.72:
		return "hurt" # Only the first moments of the i-frame window.
	if _is_attacking:
		if legs_lost:
			return "crouch_slash"
		return "attack" if is_on_floor() else "jump_attack"
	if legs_lost:
		return "crouch"
	if not is_on_floor():
		return "jump"
	if absf(velocity.x) > 10.0:
		return "walk"
	return "idle"


func _play_anim(name: String) -> void:
	if _sprite.animation != name:
		# Bottom-centre this animation's frames on the feet.
		var size: Vector2 = ANIM_FRAMES.get(name, Vector2(48, 48))
		_sprite.offset = Vector2(-size.x * 0.5, -size.y)
	_sprite.play(name)
