# vfx_telegraph.gd
# The warning an enemy shows while it winds up: a ring at the TRUE strike radius that
# fills as the windup completes, tracking the enemy as it moves.
#
# The combat contract is "every enemy commits to a telegraphed strike, and hitting it
# during the windup interrupts" — but the only tell was the sprite pulsing red. That
# says *something* is coming; it says nothing about WHERE it lands or HOW FAR it
# reaches, which is exactly the information needed to step out of it or trade into it.
# A walker's 30px swipe and a lunger's 66px commit looked the same.
#
# The ring is drawn at `strike_radius`, so it is the real danger zone, and the fill
# sweeping to full is the real remaining windup time. When it completes, the strike
# lands. Procedural for that reason — it has to follow numbers that get retuned.
extends Node2D

var color: Color = Color("e74c3c")
var radius: float = 30.0
var duration: float = 0.5
var follow: Node2D = null
var follow_offset: Vector2 = Vector2(0.0, -10.0)

var _elapsed: float = 0.0
# Set when the windup is interrupted, so the ring collapses instead of completing —
# the visual has to agree with the fact that the strike is no longer coming.
var _cancelled: bool = false


func _ready() -> void:
	z_index = 3 # Below the player's own effects; this is world-level information.


func cancel() -> void:
	_cancelled = true


func _process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(follow):
		queue_free()
		return
	global_position = follow.global_position + follow_offset
	if _cancelled or _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / duration, 0.0, 1.0)

	# Outer boundary: where the strike reaches. Always visible, so range is readable
	# from the first frame of the windup rather than only at the end.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.5), 1.0, true)

	# The fill closes in as the windup completes: a shrinking gap between the filled
	# disc and the boundary reads as "time left" without a bar.
	var filled: float = radius * t
	draw_circle(Vector2.ZERO, filled, Color(color, 0.18 + 0.16 * t))
	draw_arc(Vector2.ZERO, filled, 0.0, TAU, 28, Color(color.lightened(0.3), 0.75), 1.0, true)

	# A brighter flare in the last moments — the "now" cue for dodging or interrupting.
	if t > 0.75:
		var punch: float = (t - 0.75) / 0.25
		draw_arc(
			Vector2.ZERO, radius, 0.0, TAU, 32,
			Color(color.lightened(0.5), 0.5 + 0.5 * punch), 1.0 + punch, true
		)
