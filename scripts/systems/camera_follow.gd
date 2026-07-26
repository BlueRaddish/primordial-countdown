# camera_follow.gd
# Follows a target node with smoothing. Attach to a Camera2D.
extends Camera2D

@export var target_path: NodePath
@export var smoothing: float = 8.0
@export var look_ahead: float = 44.0

# How fast the look-ahead offset itself slides between directions. The offset used to
# be sign(velocity.x) * look_ahead, which is a step function: a single frame of
# reversed velocity — landing, brushing a wall, being knocked back — teleported the
# camera the full width of the offset and back. Easing the offset means the camera
# leads where you are *going* without lurching every time you change your mind.
@export var look_ahead_smoothing: float = 3.5

# Below this the target counts as stationary and the camera recentres, so standing
# still does not leave the view hanging off to one side.
@export var look_ahead_min_speed: float = 12.0

# Extra height shown while airborne, so a jump reveals what you are jumping toward
# rather than filling the screen with the ground you just left.
@export var air_look_up: float = 14.0

var _target: Node2D
var _look_offset: float = 0.0


func _ready() -> void:
	if target_path:
		_target = get_node_or_null(target_path) as Node2D


func _physics_process(delta: float) -> void:
	if not _target:
		return

	var desired_offset: float = 0.0
	var vertical: float = 0.0
	if _target is CharacterBody2D:
		var cb: CharacterBody2D = _target as CharacterBody2D
		if absf(cb.velocity.x) > look_ahead_min_speed:
			# Scale with how fast you are actually moving, so a walk leads less than a
			# dash and the camera is not permanently pinned to its maximum.
			var speed_t: float = clampf(absf(cb.velocity.x) / 200.0, 0.0, 1.0)
			desired_offset = signf(cb.velocity.x) * look_ahead * speed_t
		if not cb.is_on_floor():
			vertical = -air_look_up

	_look_offset = lerpf(
		_look_offset, desired_offset, 1.0 - exp(-look_ahead_smoothing * delta)
	)

	var target_pos: Vector2 = _target.global_position
	target_pos.x += _look_offset
	target_pos.y += vertical

	global_position = global_position.lerp(target_pos, 1.0 - exp(-smoothing * delta))
