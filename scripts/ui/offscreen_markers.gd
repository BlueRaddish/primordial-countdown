# offscreen_markers.gd
# A red glow along the screen edge, pointing at enemies that are off camera.
#
# WHY: the arena is 1080px wide against a 640px viewport, so most of it is out of frame
# at any moment. Hunting for the last enemy of a wave by walking blindly left and right
# is dead time, and it got worse when the camera zoomed in to 1.6.
#
# This replaced a set of 5px triangles at z_index -1, which were technically correct and
# effectively invisible — small, static, and drawn behind everything. The glow is the
# same information at a size you cannot miss: WHICH EDGE, and HOW CLOSE.
#
# Deliberately still not a minimap. It shows direction and proximity, never a count or a
# position, so it answers "which way, and how urgent" without removing the need to look
# at the arena.
#
# Drawn in the HUD's CanvasLayer, so coordinates here are screen space (640x360).
extends Control

# How far in from the edge the glow reaches, and how far along the edge it spreads.
const GLOW_DEPTH: float = 34.0
const GLOW_SPREAD: float = 130.0
# Number of strips used to fake the gradient. More is smoother and costs nothing at
# this size.
const GLOW_STEPS: int = 9

const EDGE_PAD: float = 10.0       # treat "nearly off screen" as off screen
const FAR_DISTANCE: float = 1200.0 # beyond this the glow is at its faintest

const NEAR_COLOR: Color = Color(1.0, 0.16, 0.16)
const FAR_COLOR: Color = Color(0.7, 0.15, 0.15)
const BOSS_COLOR: Color = Color(1.0, 0.5, 0.05)

# Slow deliberate breathing, not a strobe — this sits in peripheral vision for the whole
# wave, and anything faster becomes exhausting rather than informative.
const PULSE_SPEED: float = 2.4
const PULSE_MIN: float = 0.55
# Ceiling on how much a single edge can accumulate, so six enemies on one side glow
# urgently rather than turning the border into a solid red wall.
const EDGE_ALPHA_CAP: float = 0.95

var _player: Node2D
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchors are set for tidiness, but nothing here depends on them resolving — see
	# the note in _draw().
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never clip the glow to a zero-size rect.
	clip_contents = false
	# Sits at 0, not -1: the old value put it behind every other HUD element, which is
	# part of why it could not be seen. The glow hugs the borders and the readouts live
	# in the top-left corner, so they do not fight for the same pixels.
	z_index = 0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not GameState.is_run_active:
		return
	# Read the viewport directly rather than this Control's own `size`.
	#
	# THIS is why the previous markers were invisible: `size` was (0,0). Calling
	# set_anchors_preset() in _ready() sets the anchors, but the layout that turns those
	# anchors into a real size had not run yet, so every _draw() bailed on the zero-size
	# guard and nothing was ever drawn. The viewport rect needs no layout pass and is
	# the actual thing the coordinates are measured against anyway.
	var view: Vector2 = get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	# Reduce-flashing keeps the information and drops the pulse, same contract as every
	# other telegraph in the game.
	var pulse: float = 1.0
	if not GameState.reduce_flashing:
		pulse = PULSE_MIN + (1.0 - PULSE_MIN) * (0.5 + 0.5 * sin(_time * PULSE_SPEED))

	var rect: Rect2 = Rect2(
		Vector2(EDGE_PAD, EDGE_PAD), view - Vector2(EDGE_PAD, EDGE_PAD) * 2.0
	)

	# Strongest signal per edge rather than one glow per enemy: a crowd on the left is
	# still "danger, left", and stacking translucent bands would just saturate.
	# [left, right, top, bottom] -> {alpha, along, colour}
	var edges: Array[Dictionary] = [{}, {}, {}, {}]

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var e: Node2D = enemy as Node2D
		# Canvas position already accounts for the camera zoom and the 640x360 stretch.
		var screen_pos: Vector2 = e.get_global_transform_with_canvas().origin
		if rect.has_point(screen_pos):
			continue # visible; the enemy speaks for itself

		var idx: int = _edge_index(screen_pos, view)
		var strength: float = _strength(e)
		var colour: Color = BOSS_COLOR if e is BossEnemy else NEAR_COLOR.lerp(
			FAR_COLOR, 1.0 - strength
		)
		var along: float = clampf(
			screen_pos.y if idx < 2 else screen_pos.x,
			0.0,
			view.y if idx < 2 else view.x
		)
		var prev: Dictionary = edges[idx]
		if prev.is_empty() or strength > (prev["a"] as float):
			edges[idx] = {"a": strength, "along": along, "c": colour}

	for i: int in range(4):
		var d: Dictionary = edges[i]
		if d.is_empty():
			continue
		_draw_edge_glow(
			i, view, d["along"] as float,
			minf((d["a"] as float) * pulse, EDGE_ALPHA_CAP), d["c"] as Color
		)


func _edge_index(screen_pos: Vector2, view: Vector2) -> int:
	"""Which border the enemy lies past. 0 left, 1 right, 2 top, 3 bottom.

	Whichever axis it has escaped by the most wins, so something off the corner picks
	the side you would actually travel toward."""
	var over_left: float = maxf(0.0, -screen_pos.x)
	var over_right: float = maxf(0.0, screen_pos.x - view.x)
	var over_top: float = maxf(0.0, -screen_pos.y)
	var over_bottom: float = maxf(0.0, screen_pos.y - view.y)
	var worst: float = maxf(maxf(over_left, over_right), maxf(over_top, over_bottom))
	if worst == over_left and over_left > 0.0:
		return 0
	if worst == over_right and over_right > 0.0:
		return 1
	if worst == over_top and over_top > 0.0:
		return 2
	if worst == over_bottom and over_bottom > 0.0:
		return 3
	# Inside the view but within EDGE_PAD of a border — pick the nearest side.
	var dl: float = screen_pos.x
	var dr: float = view.x - screen_pos.x
	var dt: float = screen_pos.y
	var db: float = view.y - screen_pos.y
	var m: float = minf(minf(dl, dr), minf(dt, db))
	if m == dl:
		return 0
	if m == dr:
		return 1
	return 2 if m == dt else 3


func _strength(enemy: Node2D) -> float:
	"""1.0 right outside the frame, falling toward 0 the further away it is."""
	if _player == null or not is_instance_valid(_player):
		return 1.0
	var d: float = _player.global_position.distance_to(enemy.global_position)
	# Floor of 0.4 rather than 0.15: even a distant straggler has to be findable,
	# which is the whole reason the indicator exists.
	return clampf(1.0 - d / FAR_DISTANCE, 0.4, 1.0)


func _draw_edge_glow(
	edge: int, view: Vector2, along: float, alpha: float, colour: Color
) -> void:
	"""A band hugging one border, brightest at the edge and fading inward.

	Built from a few stacked rects rather than a gradient texture: at this size the
	banding is invisible, and it keeps the whole effect in code with no asset to load."""
	for i: int in range(GLOW_STEPS):
		var t: float = float(i) / float(GLOW_STEPS - 1)
		# Fades inward, and the band narrows as it goes so it reads as a glow rather
		# than a rectangle.
		var a: float = alpha * pow(1.0 - t, 2.2)
		if a <= 0.004:
			continue
		var depth: float = GLOW_DEPTH * t
		var step: float = GLOW_DEPTH / float(GLOW_STEPS)
		var spread: float = GLOW_SPREAD * (1.0 - 0.35 * t)
		var band: Color = Color(colour, a)

		match edge:
			0:
				draw_rect(Rect2(depth, along - spread, step, spread * 2.0), band)
			1:
				draw_rect(
					Rect2(view.x - depth - step, along - spread, step, spread * 2.0), band
				)
			2:
				draw_rect(Rect2(along - spread, depth, spread * 2.0, step), band)
			_:
				draw_rect(
					Rect2(along - spread, view.y - depth - step, spread * 2.0, step), band
				)
