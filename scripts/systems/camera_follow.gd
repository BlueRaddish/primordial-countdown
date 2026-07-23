# camera_follow.gd
# Follows a target node with smoothing. Attach to a Camera2D.
extends Camera2D

@export var target_path: NodePath
@export var smoothing: float = 8.0
@export var look_ahead: float = 30.0

var _target: Node2D


func _ready() -> void:
	if target_path:
		_target = get_node_or_null(target_path) as Node2D


func _physics_process(delta: float) -> void:
	if not _target:
		return

	var target_pos: Vector2 = _target.global_position
	# Look ahead in the direction the target is moving.
	if _target is CharacterBody2D:
		var cb: CharacterBody2D = _target as CharacterBody2D
		target_pos.x += sign(cb.velocity.x) * look_ahead

	global_position = global_position.lerp(target_pos, 1.0 - exp(-smoothing * delta))
