# slash_effect.gd
# Visual indicator for the player's melee attack arc.
class_name SlashEffect
extends Node2D

@export var slash_color: Color = Color("4ecdc4") # Teal arc
@export var core_color: Color = Color.WHITE     # White bright center line

var _timer: float = 0.0
var _duration: float = 0.2
var _active: bool = false
var _facing_right: bool = true


func _ready() -> void:
	visible = false


func play(duration: float, facing_right: bool) -> void:
	_duration = duration
	_timer = duration
	_active = true
	_facing_right = facing_right
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
	var alpha: float = clampf(1.0 - (progress * 0.8), 0.0, 1.0)

	var radius: float = 16.0 + progress * 8.0 # expanding outward sweep
	var start_angle: float = -PI * 0.4
	var end_angle: float = PI * 0.4

	var points_outer: PackedVector2Array = []
	var points_inner: PackedVector2Array = []
	var steps: int = 12

	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = lerpf(start_angle, end_angle, t)
		if not _facing_right:
			angle = PI - angle

		var out_r: float = radius
		# Crescent shape: thickest in center (t = 0.5), tapering at ends
		var thickness: float = 8.0 * (1.0 - absf(t - 0.5) * 1.8)
		thickness = maxf(thickness, 1.0)
		var in_r: float = maxf(out_r - thickness, 2.0)

		var cos_a: float = cos(angle)
		var sin_a: float = sin(angle)

		points_outer.append(Vector2(cos_a * out_r, sin_a * out_r))
		points_inner.append(Vector2(cos_a * in_r, sin_a * in_r))

	# Build crescent polygon
	var poly: PackedVector2Array = []
	for p: Vector2 in points_outer:
		poly.append(p)

	# Add inner points in reverse order to close polygon
	var count: int = points_inner.size()
	for i: int in range(count - 1, -1, -1):
		poly.append(points_inner[i])

	var draw_slash_col: Color = slash_color
	draw_slash_col.a *= alpha
	var draw_core_col: Color = core_color
	draw_core_col.a *= alpha

	if poly.size() > 2:
		draw_colored_polygon(poly, draw_slash_col)
		draw_polyline(points_outer, draw_core_col, 2.0)
