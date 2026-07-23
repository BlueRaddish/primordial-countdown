# player.gd
# Player controller — side-view platformer movement.
# Milestone 1: move left/right, jump, land. No combat.
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

# --- Internal state ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement(delta)
	_update_animation()

	move_and_slide()

	_was_on_floor = is_on_floor()


# ---- Gravity ----

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var grav := gravity
	if velocity.y > 0.0:
		grav *= fall_gravity_mult
	velocity.y = minf(velocity.y + grav * delta, max_fall_speed)


# ---- Jump ----

func _handle_timers(delta: float) -> void:
	# Coyote time: keep permission to jump briefly after leaving the floor.
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	# Jump buffer: remember a jump press briefly before landing.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta


func _handle_jump() -> void:
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_force
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# Variable height: cut upward velocity when the player releases early.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.4


# ---- Horizontal movement ----

func _handle_horizontal_movement(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
	else:
		var fric := friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


# ---- Animation ----

func _update_animation() -> void:
	if not _sprite:
		return

	# Flip sprite to face movement direction.
	if velocity.x > 0.1:
		_sprite.flip_h = false
	elif velocity.x < -0.1:
		_sprite.flip_h = true

	if not is_on_floor():
		_sprite.play("jump")
	elif absf(velocity.x) > 10.0:
		_sprite.play("walk")
	else:
		_sprite.play("idle")
