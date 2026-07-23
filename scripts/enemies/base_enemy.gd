# base_enemy.gd
# Basic enemy with patrol/chase/hurt/dead states.
# All enemy types extend from this.
extends CharacterBody2D

enum State { PATROL, CHASE, HURT, DEAD }

# --- Tuning ---
@export var max_health: float = 50.0
@export var move_speed: float = 40.0
@export var chase_speed: float = 65.0
@export var detection_range: float = 100.0
@export var contact_damage: float = 15.0
@export var contact_cooldown: float = 0.8
@export var gravity: float = 800.0
@export var knockback_decay: float = 400.0
@export var patrol_distance: float = 80.0

# --- Internal state ---
var _current_health: float
var _state: State = State.PATROL
var _patrol_direction: float = 1.0
var _patrol_origin_x: float = 0.0
var _contact_timer: float = 0.0
var _hurt_timer: float = 0.0
var _death_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	_current_health = max_health
	_patrol_origin_x = global_position.x


func _physics_process(delta: float) -> void:
	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			_process_dead(delta)
			return

	# Gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# Contact damage cooldown.
	_contact_timer -= delta

	# Flash effect.
	if _flash_timer > 0.0:
		_flash_timer -= delta
		_sprite.modulate = Color(2.0, 0.5, 0.5) if fmod(_flash_timer, 0.1) > 0.05 else Color.WHITE
	else:
		_sprite.modulate = Color.WHITE

	move_and_slide()
	_update_animation()
	_check_contact_damage()


# ---- State: PATROL ----

func _process_patrol(delta: float) -> void:
	velocity.x = _patrol_direction * move_speed

	# Reverse at patrol bounds.
	var dist_from_origin: float = global_position.x - _patrol_origin_x
	if absf(dist_from_origin) > patrol_distance:
		_patrol_direction *= -1.0
		velocity.x = _patrol_direction * move_speed

	# Check for player in range.
	var player: Node2D = _find_player()
	if player and global_position.distance_to(player.global_position) < detection_range:
		_state = State.CHASE


# ---- State: CHASE ----

func _process_chase(delta: float) -> void:
	var player: Node2D = _find_player()
	if not player:
		_state = State.PATROL
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist > detection_range * 1.5:
		_state = State.PATROL
		return

	var dir: float = sign(player.global_position.x - global_position.x)
	velocity.x = dir * chase_speed


# ---- State: HURT ----

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, knockback_decay * delta)
	if _hurt_timer <= 0.0:
		_state = State.CHASE


# ---- State: DEAD ----

func _process_dead(delta: float) -> void:
	_death_timer -= delta
	_sprite.modulate.a = clampf(_death_timer / 0.3, 0.0, 1.0)
	if _death_timer <= 0.0:
		queue_free()


# ---- Damage ----

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _state == State.DEAD:
		return

	_current_health -= amount
	_flash_timer = 0.2

	# Apply knockback.
	velocity = knockback

	if _current_health <= 0.0:
		_die()
	else:
		_state = State.HURT
		_hurt_timer = 0.25

	EventBus.enemy_hit.emit(self, amount, knockback)


func _die() -> void:
	_state = State.DEAD
	_death_timer = 0.4
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
			var dir: float = sign(collider_node.global_position.x - global_position.x)
			if dir == 0.0:
				dir = 1.0
			collider.call("take_damage", contact_damage, Vector2(dir, -0.5).normalized())
			_contact_timer = contact_cooldown
			break


# ---- Helpers ----

func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


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
