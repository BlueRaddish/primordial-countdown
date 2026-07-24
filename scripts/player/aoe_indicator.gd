# aoe_indicator.gd
# Generic AoE visualization node.
# Draws a solid color fill at the given position with the given radius.
# Self-destructs after the animation completes.
class_name AoEIndicator
extends Node2D

var aoe_center: Vector2 = Vector2.ZERO
var aoe_radius: float = 30.0
var aoe_color: Color = Color("4ecdc4")
var is_directional: bool = false
var direction: Vector2 = Vector2.RIGHT

var _lifetime: float = 0.25
var _elapsed: float = 0.0
var _scale_factor: float = 0.0


func _ready() -> void:
	global_position = aoe_center
	z_index = 5 # Render above most things.


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed / _lifetime

	if t >= 1.0:
		queue_free()
		return

	# Expand quickly then fade.
	_scale_factor = ease(minf(t * 2.0, 1.0), 0.3)
	var alpha: float = 1.0 - ease(t, 2.0)
	aoe_color.a = alpha * 0.5 # Semi-transparent fill.
	queue_redraw()


func _draw() -> void:
	if is_directional:
		# Draw an arc sector toward the aim direction.
		var half_angle: float = PI / 3.0 # 60° half-width = 120° total arc
		var start_angle: float = direction.angle() - half_angle
		var points: PackedVector2Array = PackedVector2Array()
		points.append(Vector2.ZERO)
		var segments: int = 16
		var current_radius: float = aoe_radius * _scale_factor
		for i: int in range(segments + 1):
			var angle: float = start_angle + (2.0 * half_angle * float(i) / float(segments))
			points.append(Vector2(cos(angle), sin(angle)) * current_radius)
		points.append(Vector2.ZERO)
		draw_colored_polygon(points, aoe_color)
	else:
		# Draw a full circle.
		var current_radius: float = aoe_radius * _scale_factor
		var points: PackedVector2Array = PackedVector2Array()
		var segments: int = 24
		for i: int in range(segments):
			var angle: float = TAU * float(i) / float(segments)
			points.append(Vector2(cos(angle), sin(angle)) * current_radius)
		draw_colored_polygon(points, aoe_color)
