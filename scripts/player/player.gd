# player.gd
# Player controller — side-view platformer movement + 360° mouse-aimed AoE melee combat.
extends CharacterBody2D

# --- Movement tuning ---
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

# --- Internal state ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _is_dead: bool = false

# Combat state.
var _current_health: float
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _is_attacking: bool = false
var _invincibility_timer: float = 0.0
var _facing_right: bool = true
var _aim_angle: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var _slash_effect: SlashEffect = $SlashEffect


func _ready() -> void:
	add_to_group("player")
	_current_health = max_health
	_attack_shape.disabled = true
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_hit.connect(_on_player_hit)
	# Sync health display.
	EventBus.player_health_changed.emit(_current_health, max_health)


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
	_handle_invincibility(delta)
	_update_animation()

	move_and_slide()

	_was_on_floor = is_on_floor()


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


func _handle_jump() -> void:
	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_force
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.4


# ---- Horizontal movement ----

func _handle_horizontal_movement(delta: float) -> void:
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

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	_is_attacking = true
	_attack_timer = attack_duration
	_attack_cooldown_timer = attack_cooldown

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

	if _slash_effect:
		_slash_effect.play(attack_duration, _aim_angle)


func _finish_attack() -> void:
	_is_attacking = false
	_attack_shape.disabled = true
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
			body.call("take_damage", attack_damage, kb)
			hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)


# ---- Damage / Health ----

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_dead or _invincibility_timer > 0.0:
		return
	GameState.damage_player(amount, knockback_dir)


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
