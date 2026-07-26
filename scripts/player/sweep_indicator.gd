# sweep_indicator.gd
# The visual for a dash-attack's travelling hitbox.
#
# A single AoE flash at the cast point was actively misleading once the hitbox started
# moving: it showed a circle where the dash STARTED while the damage was happening
# somewhere else entirely, so there was no way to tell the hitbox was travelling with
# you — or how far it reached.
#
# This follows the player for as long as the sweep is live and leaves a fading trail
# of where it has been, so the swept path is legible as a path rather than a blink.
# The leading edge is drawn as a ring at full strength: that ring IS the hitbox, at
# the real radius, so what you see is what damages.
#
# Deliberately NOT a `class_name` — consumers preload it. A newly declared global class
# is invisible until the editor rescans, which breaks headless runs against an existing
# import cache.
extends Node2D

# The node to follow, usually the player.
var target: Node2D = null
# Where the hitbox sits relative to the target (AbilityManager centres it on the
# player's torso, not their feet).
var target_offset: Vector2 = Vector2(0.0, -10.0)
var radius: float = 26.0
var color: Color = Color("4ecdc4")
# How long the hitbox is live. Matches the impulse duration.
var duration: float = 0.25

# The trail lingers a little past the hitbox so the path stays readable after the
# dash ends, rather than vanishing on the same frame.
const FADE_TAIL: float = 0.22
const MAX_POINTS: int = 24

var _elapsed: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	# Independent of any parent transform, so the stored world positions can be drawn
	# directly without converting every frame.
	top_level = true
	global_position = Vector2.ZERO
	z_index = 6 # Just above AoEIndicator, so the live edge is never buried.
	_sample()


func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed <= duration:
		_sample()
	elif _elapsed >= duration + FADE_TAIL:
		queue_free()
		return

	queue_redraw()


func _sample() -> void:
	if not is_instance_valid(target):
		return
	var p: Vector2 = target.global_position + target_offset
	# Skip near-duplicate samples so standing still does not stack 15 circles in one
	# spot and read as a solid blob.
	if _points.size() > 0 and _points[_points.size() - 1].distance_to(p) < 2.0:
		return
	_points.append(p)
	if _points.size() > MAX_POINTS:
		_points.remove_at(0)


func _draw() -> void:
	if _points.is_empty():
		return

	# Everything fades together once the hitbox has expired.
	var life: float = 1.0
	if _elapsed > duration:
		life = 1.0 - clampf((_elapsed - duration) / FADE_TAIL, 0.0, 1.0)

	var last: int = _points.size() - 1
	for i: int in range(_points.size()):
		# Oldest samples are faintest, so the trail reads as direction of travel.
		var age: float = float(i) / float(maxi(last, 1))
		var fill: Color = Color(color, 0.10 + 0.14 * age)
		fill.a *= life
		draw_circle(_points[i], radius, fill)

	# The leading edge, at the true hitbox radius — this ring is the thing that hurts.
	var head: Vector2 = _points[last]
	draw_arc(head, radius, 0.0, TAU, 28, Color(color, 0.9 * life), 1.5, true)
	draw_circle(head, radius, Color(color, 0.18 * life))
