# slash_effect.gd
# Visual indicator for the player's 360-degree directional melee attack.
# Draws a solid color fill of the AoE shape during active frames.
class_name SlashEffect
extends Node2D

@export var slash_color: Color = Color("4ecdc4") # Teal fill
@export var aoe_radius: float = 40.0 # Match the attack hitbox reach

var _timer: float = 0.0
var _duration: float = 0.2
var _active: bool = false
var _aim_angle: float = 0.0


func _ready() -> void:
	visible = false


func play(duration: float, aim_angle: float) -> void:
	_duration = duration
	_timer = duration
	_active = true
	_aim_angle = aim_angle
	visible = true
	queue_redraw()


func stop() -> void:
	_active = false
	visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		stop()
	else:
		queue_redraw()


func _draw() -> void:
	if not _active or _duration <= 0.0:
		return

	var progress: float = 1.0 - (_timer / _duration) # 0.0 -> 1.0
	var alpha: float = clampf(1.0 - (progress * 0.6), 0.0, 1.0)

	# Solid fill arc sector toward the aim direction.
	var half_angle: float = PI * 0.42
	var start_angle: float = _aim_angle - half_angle
	var current_radius: float = aoe_radius * (0.6 + progress * 0.4)

	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	var segments: int = 20
	for i: int in range(segments + 1):
		var angle: float = start_angle + (2.0 * half_angle * float(i) / float(segments))
		points.append(Vector2(cos(angle), sin(angle)) * current_radius)
	points.append(Vector2.ZERO)

	# Solid fill.
	var fill_col: Color = slash_color
	fill_col.a = alpha * 0.45
	draw_colored_polygon(points, fill_col)

	# Bright edge outline.
	var edge_col: Color = Color.WHITE
	edge_col.a = alpha * 0.7
	var edge_points: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments + 1):
		var angle: float = start_angle + (2.0 * half_angle * float(i) / float(segments))
		edge_points.append(Vector2(cos(angle), sin(angle)) * current_radius)
	draw_polyline(edge_points, edge_col, 1.5)
