# player.gd
# Player controller — side-view platformer movement + 360° mouse-aimed AoE melee combat.
# Stats are rebuilt from TraitManager on every trait change via recalculate_from_traits().
extends CharacterBody2D

# --- Base constants (never change) ---
const BASE_MOVE_SPEED: float = 120.0
const BASE_ACCELERATION: float = 900.0
const BASE_JUMP_FORCE: float = -260.0
const BASE_ATTACK_DAMAGE: float = 25.0
const BASE_MELEE_RANGE: float = 24.0 # Offset of hitbox center from player

# --- Live values (rebuilt from traits) ---
@export var move_speed: float = 120.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var air_friction: float = 400.0

# --- Jump tuning ---
@export var jump_force: float = -260.0
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
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_hit.connect(_on_player_hit)
	# Sync health display.
	EventBus.player_health_changed.emit(GameState.player_health, GameState.player_max_health)


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
	"""Rebuild all live stats from current trait state."""
	# Movement modifiers.
	var leg_mod: float = trait_mgr.get_modifier("legs")
	move_speed = BASE_MOVE_SPEED * leg_mod
	acceleration = BASE_ACCELERATION * leg_mod
	jump_force = BASE_JUMP_FORCE * trait_mgr.get_leg_jump_mod()

	# Combat modifiers.
	var arm_damage_mod: float = trait_mgr.get_arm_damage_mod()
	attack_damage = BASE_ATTACK_DAMAGE * arm_damage_mod

	# Capability gates.
	movement_enabled = not trait_mgr.is_movement_blocked()
	_can_jump = trait_mgr.can_jump()
	arms_blocked = trait_mgr.is_arms_blocked()

	# Update hitbox offset based on arm range modifier.
	var arm_mod: float = trait_mgr.get_modifier("arms")
	if _attack_shape:
		_attack_shape.position.x = BASE_MELEE_RANGE * maxf(arm_mod, 0.2)


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

	var cd_mult: float = 1.0
	if _status_effects:
		cd_mult = _status_effects.get_attack_cooldown_mult()
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
