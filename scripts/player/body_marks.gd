# body_marks.gd
# Procedural overlay that makes the player's body visibly change as it devolves.
# Child node of Player, sitting behind the sprite.
#
# The whole fantasy of the run is watching a body come apart and improvise around
# the wreckage, and until now none of that was visible — traits and evolved traits
# only ever existed as numbers and HUD rows. This draws the parts that grew back.
#
# Everything here is drawn rather than authored as art, for the same reason the AoE
# indicators are: the shapes need to follow trait state exactly, and a placeholder
# that is always correct beats a sprite sheet that goes stale every time a trait is
# retuned. Swapping in real art later means replacing this node, nothing else.
class_name BodyMarks
extends Node2D

# Body box the marks are drawn around, matching the player's collision shape.
const BODY_HALF_W: float = 7.0
const BODY_HALF_H: float = 10.0

# --- Wings, built by tools/build_wings.py from the Gothicvania demon ---
# preload rather than a scene-exported Texture2D: this node is created in code paths the
# headless test runner exercises, and an unset export there fails as a null draw with no
# hint as to why.
const WING_TEXTURE: Texture2D = preload("res://assets/sprites/player/wings_bat.png")
# One frame of the strip, and the point inside it where the wing meets the back. Both
# come straight out of the build script — it prints them when it runs. The strip holds a
# single wing; _draw_wings() mirrors it to make the pair.
const WING_FRAME: Vector2 = Vector2(86.0, 93.0)
const WING_PIVOT: Vector2 = Vector2(6.0, 49.0)
# The character sprite is drawn at 0.6 (Player.SPRITE_SCALE), and the wings are further
# scaled to a wingspan of roughly 1.8 body widths — big enough to read as the reason you
# can now hover, small enough that they do not swallow the arena.
const WING_SCALE: float = 0.30
# Shoulder blades, in this node's local space. BodyMarks sits at the body's centre and
# the body runs -10..+10, so this is high on the back.
#
# Measured, not guessed: on the demon the wings meet the body about a fifth of the way
# down its torso. Anchoring at -3 put them a third of the way down instead, and on the
# down-stroke the wings reached the character's knees and read as growing out of its
# legs rather than its back.
const WING_ANCHOR: Vector2 = Vector2(0.0, -7.0)

# --- State, pushed in by the player on every trait recalculation ---
var has_wings: bool = false
var has_tail: bool = false
var has_claws: bool = false
var has_gills: bool = false
# Set when Hide or Plates has grown; the rim is drawn in that trait's colour.
var armor_color: Color = Color.TRANSPARENT

var wing_color: Color = Color("aed6f1")
var tail_color: Color = Color("bb8fce")
var claw_color: Color = Color("e8dcc8")
var gill_color: Color = Color("76d7c4")

# --- Per-frame state, pushed in by the player ---
var facing_right: bool = true
var airborne: bool = false
var horizontal_speed: float = 0.0

var _phase: float = 0.0


func _ready() -> void:
	# Behind the character sprite, so wings and tail read as being *on* the far side
	# of the body rather than pasted over its face.
	z_index = -1
	set_process(false)


func _process(delta: float) -> void:
	# Wings beat faster in the air; the tail sways with how fast you are moving.
	_phase += delta * (9.0 if airborne else 3.0)
	queue_redraw()


func set_marks(wings: bool, tail: bool, claws: bool, gills: bool, armor: Color) -> void:
	"""Called from the player whenever trait state changes."""
	has_wings = wings
	has_tail = tail
	has_claws = claws
	has_gills = gills
	armor_color = armor
	# Nothing grown means nothing to animate — stay off the frame budget entirely.
	set_process(_has_anything())
	queue_redraw()


func set_motion(is_facing_right: bool, is_airborne: bool, speed_x: float) -> void:
	facing_right = is_facing_right
	airborne = is_airborne
	horizontal_speed = speed_x


func _has_anything() -> bool:
	return has_wings or has_tail or has_claws or has_gills or armor_color.a > 0.0


func _draw() -> void:
	if not _has_anything():
		return
	if armor_color.a > 0.0:
		_draw_armor_rim()
	if has_wings:
		_draw_wings()
	if has_tail:
		_draw_tail()
	if has_claws:
		_draw_claws()
	if has_gills:
		_draw_gills()


func _draw_armor_rim() -> void:
	"""A thick plated edge just outside the silhouette. Drawn as a rim rather than a
	fill because this node sits behind the sprite — an overlay would be invisible."""
	var rect: Rect2 = Rect2(
		-BODY_HALF_W - 2.0, -BODY_HALF_H - 2.0,
		(BODY_HALF_W + 2.0) * 2.0, (BODY_HALF_H + 2.0) * 2.0
	)
	draw_rect(rect, armor_color, false, 3.0)
	# Two seams across the rim so it reads as plating rather than an outline.
	for y: float in [-3.0, 4.0]:
		draw_line(
			Vector2(-BODY_HALF_W - 2.0, y), Vector2(BODY_HALF_W + 2.0, y),
			Color(armor_color, 0.55), 1.0
		)


func _draw_wings() -> void:
	"""Real bat wings, lifted off Gothicvania's demon by tools/build_wings.py.

	This replaced a five-point polygon that beat up and down. The polygon was honest
	placeholder work, but Wings is an evolved trait — the reward for losing something —
	and a flat quad made the payoff look unfinished. The demon is by ansimuz, same as
	the hero sprite, so the membrane, outline weight and shading all match the body
	they are attached to.

	The strip is greyscale on purpose so `wing_color` still drives the colour, exactly
	as it did for the polygon. Trait colours stay the trait system's business."""
	var tex: Texture2D = WING_TEXTURE
	if tex == null:
		return

	# Three poses: up-stroke, spread, down-stroke, with spread passed through on the way
	# back so the loop reads as a beat rather than a snap to the top.
	const ORDER: Array[int] = [0, 1, 2, 1]
	# Airborne already drives _phase three times faster (see _process), so this is the
	# beat *shape*, not its speed.
	var step: int = ORDER[int(_phase * 1.6) % ORDER.size()]
	var src: Rect2 = Rect2(
		float(step) * WING_FRAME.x, 0.0, WING_FRAME.x, WING_FRAME.y
	)

	# Drawn at the character sprite's own scale, so the wings resample identically to
	# the body instead of crawling against it as the camera moves. The pivot is the point
	# where the wing meets the back, so it stays pinned there through the whole beat.
	var dst: Rect2 = Rect2(
		WING_ANCHOR - WING_PIVOT * WING_SCALE, WING_FRAME * WING_SCALE
	)
	# A beat lifts the body a little; on the ground the feet say otherwise, so only in air.
	if airborne:
		dst.position.y -= sin(_phase) * 1.2

	var tint: Color = Color(wing_color, 0.92)
	# The texture holds one wing. Drawing it, then drawing it mirrored about x = 0 — the
	# body's centre line — gives the pair. The far wing is deliberately dimmer: without
	# it the two overlap into one flat shape, and this is the cheapest depth cue there is.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(tex, dst, src, Color(tint, tint.a * 0.72).darkened(0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect_region(tex, dst, src, tint)


func _draw_tail() -> void:
	"""A tapering curve trailing behind, swaying against the direction of travel —
	which is exactly what it is for: counterweight."""
	var back: float = -1.0 if facing_right else 1.0
	var sway: float = sin(_phase * 1.4) * 2.0 - clampf(horizontal_speed / 60.0, -3.0, 3.0) * back
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var t: float = float(i) / 5.0
		points.append(Vector2(
			back * (3.0 + t * 15.0),
			5.0 - t * 2.0 + sin(_phase + t * 2.4) * sway * t
		))
	# Taper by drawing each segment thinner than the last.
	for i: int in range(points.size() - 1):
		var width: float = 3.4 - float(i) * 0.5
		draw_line(points[i], points[i + 1], tail_color, maxf(width, 1.0))


func _draw_claws() -> void:
	"""Three short hooks past the silhouette at hand height. Claws have almost no
	reach, and the marks are deliberately stubby to say so."""
	var side: float = 1.0 if facing_right else -1.0
	for i: int in range(3):
		var y: float = -3.0 + float(i) * 3.0
		var from: Vector2 = Vector2(side * (BODY_HALF_W - 1.0), y)
		var to: Vector2 = Vector2(side * (BODY_HALF_W + 5.0), y + 2.0)
		draw_line(from, to, claw_color, 1.6)


func _draw_gills() -> void:
	var flutter: float = 0.6 + 0.4 * sin(_phase * 2.0)
	for side: float in [-1.0, 1.0]:
		for i: int in range(3):
			var y: float = -7.0 + float(i) * 2.6
			draw_line(
				Vector2(side * (BODY_HALF_W - 1.0), y),
				Vector2(side * (BODY_HALF_W + 2.5), y),
				Color(gill_color, flutter), 1.2
			)
