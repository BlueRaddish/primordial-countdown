# vfx_hitbox.gd
# Draws the REAL hitbox of an attack — the exact shape that decides whether something
# was hit — as a solid translucent form underneath the animation.
#
# Why both: an animation is a lie by design. It is drawn for feel, so it flourishes
# past its own reach, and against a telegraph-based combat contract that makes it
# genuinely hard to learn what connects. Showing the true shape beneath the flourish
# means what you SEE is what HITS, and the animation on top still gives it weight.
#
# Procedural on purpose. Every shape here is read from the live gameplay numbers
# (`aoe_radius`, the AttackHitbox's RectangleShape2D), so retuning a radius updates the
# visual for free. A sprite would need re-authoring and would quietly go stale.
#
# Layering: this sits at z_index 4, the sprite effects at 8, so the animation always
# reads over the shape rather than the other way round.
#
# No `class_name` — preloaded by consumers, so headless runs do not depend on the
# editor having rescanned.
extends Node2D

enum Shape { CIRCLE, RECT, ARC }

var shape: Shape = Shape.CIRCLE
var color: Color = Color("4ecdc4")
var radius: float = 30.0
# For RECT: full extents, already in world pixels. Rotated by `angle`.
var rect_size: Vector2 = Vector2(40.0, 28.0)
# For ARC: half-width of the sector, in radians.
var arc_half_angle: float = PI / 3.0
var angle: float = 0.0
var lifetime: float = 0.2
# Follows this node if set, so a travelling hitbox keeps showing where it truly is.
var follow: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = 4 # Under the animation, over the world.


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	if is_instance_valid(follow):
		global_position = follow.global_position + follow_offset
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / lifetime, 0.0, 1.0)
	# Holds at full strength for the first half of the window, then goes — so the shape
	# is legible for as long as it is actually dangerous.
	var alpha: float = 1.0 - ease(clampf((t - 0.4) / 0.6, 0.0, 1.0), 1.4)

	var fill: Color = Color(color, 0.28 * alpha)
	var edge: Color = Color(color.lightened(0.35), 0.85 * alpha)

	match shape:
		Shape.RECT:
			var half: Vector2 = rect_size * 0.5
			var pts: PackedVector2Array = PackedVector2Array([
				Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y),
			])
			var rotated: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in pts:
				rotated.append(p.rotated(angle))
			draw_colored_polygon(rotated, fill)
			rotated.append(rotated[0])
			draw_polyline(rotated, edge, 1.0)

		Shape.ARC:
			var pts2: PackedVector2Array = PackedVector2Array()
			pts2.append(Vector2.ZERO)
			var segs: int = 20
			for i: int in range(segs + 1):
				var a: float = angle - arc_half_angle + (2.0 * arc_half_angle * float(i) / float(segs))
				pts2.append(Vector2(cos(a), sin(a)) * radius)
			pts2.append(Vector2.ZERO)
			draw_colored_polygon(pts2, fill)
			draw_polyline(pts2, edge, 1.0)

		_:
			draw_circle(Vector2.ZERO, radius, fill)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, edge, 1.0, true)
