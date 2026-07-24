# player.gd
# Player controller — side-view platformer movement + 360° mouse-aimed AoE melee combat.
# Stats are rebuilt from TraitManager on every trait change via recalculate_from_traits().
extends CharacterBody2D

# --- Base constants (never change) ---
const BASE_MOVE_SPEED: float = 120.0
const BASE_ACCELERATION: float = 900.0
# Peak rise = JUMP_FORCE^2 / (2 * gravity) = 330^2 / 1600 = 68 px.
# The arena's optional high routes are built against that number.
const BASE_JUMP_FORCE: float = -330.0
const BASE_ATTACK_DAMAGE: float = 25.0
const BASE_MELEE_RANGE: float = 24.0 # Offset of hitbox center from player
const BASE_MELEE_LENGTH: float = 40.0 # Hitbox length along the aim direction

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

# --- Combat tuning ---
@export var max_health: float = 100.0
@export var attack_damage: float = 25.0
@export var attack_duration: float = 0.2
@export var attack_cooldown: float = 0.35
@export var knockback_force: float = 220.0
@export var knockback_up: float = -80.0
@export var invincibility_duration: float = 0.6
@export var hit_knockback_force: float = 150.0
@export var melee_aoe_color: Color = Color("4ecdc4")

# --- Capability gates (set by TraitManager) ---
var movement_enabled: bool = true
var _can_jump: bool = true
var arms_blocked: bool = false

# --- Live trait-derived stats (rebuilt by recalculate_from_traits) ---
var health_regen: float = 1.5 # Gut: health per second
var attack_cooldown_mult: float = 1.0 # Throat: swing recovery
var intimidation_radius: float = 92.0 # Speech: aura that slows nearby enemies
var intimidation_slow: float = 0.35
var vision_mod: float = 1.0 # Eyes: world brightness

# --- Internal state ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _is_dead: bool = false
var _spawn_position: Vector2 = Vector2.ZERO

# Combat state.
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _is_attacking: bool = false
var _invincibility_timer: float = 0.0
var _impulse_timer: float = 0.0
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
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement(delta)
	_handle_attack(delta)
	_handle_skill_input()
	_handle_invincibility(delta)
	_handle_regen(delta)
	_update_animation()

	move_and_slide()

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

	# Arms: damage and reach.
	attack_damage = BASE_ATTACK_DAMAGE * trait_mgr.get_arm_damage_mod()
	_apply_melee_reach(trait_mgr.get_arm_range_mod())

	# Gut: passive health regen.
	health_regen = trait_mgr.get_gut_regen_rate()

	# Throat: how fast the player recovers between swings.
	attack_cooldown_mult = trait_mgr.get_throat_cooldown_mult()

	# Speech: passive intimidation aura read by enemies while chasing.
	intimidation_radius = trait_mgr.get_intimidation_radius()
	intimidation_slow = trait_mgr.get_intimidation_slow()

	# Eyes: world brightness.
	vision_mod = trait_mgr.get_eyes_vision_mod()
	_apply_vision()

	# Capability gates.
	movement_enabled = not trait_mgr.is_movement_blocked()
	_can_jump = trait_mgr.can_jump()
	arms_blocked = trait_mgr.is_arms_blocked()


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


func get_intimidation_factor(from_position: Vector2) -> float:
	"""Chase-speed multiplier applied to an enemy at the given position.
	1.0 = unaffected. Degrades to 1.0 everywhere once speech is fully lost."""
	if intimidation_radius <= 0.0 or intimidation_slow <= 0.0:
		return 1.0
	if global_position.distance_to(from_position) > intimidation_radius:
		return 1.0
	return 1.0 - intimidation_slow


func get_aim_direction() -> Vector2:
	return _aim_dir


# ---- Alternative movement (skill impulse) ----

func apply_impulse(direction: Vector2, speed: float, upward_bias: float) -> void:
	"""Alternative movement hook, used when a skill takes over locomotion."""
	if _is_dead:
		return
	var dir: Vector2 = direction
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT if _facing_right else Vector2.LEFT
	velocity = dir.normalized() * speed
	velocity.y -= upward_bias
	_impulse_timer = 0.25
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
		return
	var grav: float = gravity
	if velocity.y > 0.0:
		grav *= fall_gravity_mult
	velocity.y = minf(velocity.y + grav * delta, max_fall_speed)


# ---- Jump ----

func _handle_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _impulse_timer > 0.0:
		_impulse_timer -= delta


func _handle_jump() -> void:
	if not _can_jump:
		return
	var floor_jump: bool = is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and floor_jump:
		velocity.y = jump_force
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.4


# ---- Horizontal movement ----

func _handle_horizontal_movement(delta: float) -> void:
	# A skill impulse owns velocity for its brief window.
	if _impulse_timer > 0.0:
		return

	if not movement_enabled:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	if _is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, friction * 0.5 * delta)
		return

	var input_dir: float = Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
		_facing_right = input_dir > 0.0
	else:
		var fric: float = friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


# ---- 360° Mouse-Aimed AoE Attack ----

func _handle_attack(delta: float) -> void:
	_attack_cooldown_timer -= delta

	if _is_attacking:
		_attack_timer -= delta
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

	# Throat sets the baseline swing recovery; a buff (Second Wind) can cut it back down.
	var cd_mult: float = attack_cooldown_mult
	if _status_effects:
		cd_mult *= _status_effects.get_attack_cooldown_mult()
	_attack_cooldown_timer = attack_cooldown * cd_mult

	# Calculate mouse aim direction relative to player center.
	var player_center: Vector2 = global_position + Vector2(0.0, -10.0)
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir_to_mouse: Vector2 = mouse_pos - player_center

	if dir_to_mouse.length_squared() > 0.001:
		_aim_dir = dir_to_mouse.normalized()
	else:
		_aim_dir = Vector2.RIGHT if _facing_right else Vector2.LEFT

	_aim_angle = _aim_dir.angle()
	_facing_right = _aim_dir.x >= 0.0

	# Rotate AttackHitbox toward mouse angle.
	_attack_hitbox.rotation = _aim_angle
	_attack_shape.disabled = false

	# Show AoE fill for the melee attack.
	if _slash_effect:
		_slash_effect.play(attack_duration, _aim_angle)

	# This is the devolution clock's driver: every swing counts, landed or not.
	EventBus.attack_made.emit()


func _finish_attack() -> void:
	_is_attacking = false
	_attack_shape.disabled = true

	var damage: float = attack_damage
	if _status_effects:
		damage *= _status_effects.get_damage_mult()

	# AoE: damage ALL enemies currently overlapping the rotated hitbox.
	var hit_count: int = 0
	var overlapping: Array[Node2D] = _attack_hitbox.get_overlapping_bodies()
	for body: Node2D in overlapping:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var player_center: Vector2 = global_position + Vector2(0.0, -10.0)
			var kb_dir: Vector2 = (body.global_position - player_center).normalized()
			if kb_dir == Vector2.ZERO:
				kb_dir = _aim_dir
			var kb: Vector2 = Vector2(kb_dir.x * knockback_force, knockback_up)
			body.call("take_damage", damage, kb)
			hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)
		report_damage_dealt(damage * float(hit_count))


# ---- Skill Input ----

func _handle_skill_input() -> void:
	if not _ability_manager:
		return
	if Input.is_action_just_pressed("skill_q"):
		_ability_manager.activate_skill(0)
	elif Input.is_action_just_pressed("skill_e"):
		_ability_manager.activate_skill(1)
	elif Input.is_action_just_pressed("skill_r"):
		_ability_manager.activate_skill(2)


# ---- Damage / Health ----

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_dead or _invincibility_timer > 0.0:
		return

	var incoming: float = amount
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
	velocity = knockback_dir * hit_knockback_force
	velocity.y = minf(velocity.y, -60.0)
	_invincibility_timer = invincibility_duration


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
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		_sprite.modulate.a = 0.3 if fmod(_invincibility_timer, 0.1) > 0.05 else 1.0
	else:
		_sprite.modulate.a = 1.0


# ---- Animation ----

func _update_animation() -> void:
	if not _sprite:
		return

	if _facing_right:
		_sprite.flip_h = false
	else:
		_sprite.flip_h = true

	if _is_attacking:
		_sprite.play("attack")
	elif not is_on_floor():
		_sprite.play("jump")
	elif absf(velocity.x) > 10.0:
		_sprite.play("walk")
	else:
		_sprite.play("idle")
