# offscreen_markers.gd
# Red edge markers pointing at enemies that are off screen.
#
# WHY: the arena is 1080px wide against a 640px viewport, so at any moment most of it
# is out of frame. Hunting for the last enemy of a wave by walking blindly left and
# right is dead time, and it gets worse once the arena opens up vertically.
#
# Deliberately shows direction and proximity, never a count or a position: it should
# answer "which way, and how close" — the same question a player answers by listening —
# without turning into a minimap that removes the need to look at the arena at all.
#
# Drawn in the HUD's CanvasLayer, so coordinates here are screen space (640x360).
extends Control

const MARKER_INSET: float = 6.0    # how far in from the screen edge the tip sits
const MARKER_SIZE: float = 5.0     # half-width of the triangle's base
const EDGE_PAD: float = 10.0       # treat "nearly off screen" as off screen
const FAR_DISTANCE: float = 700.0  # beyond this a marker is at its faintest

const NEAR_COLOR: Color = Color(1.0, 0.25, 0.25, 0.95)
const FAR_COLOR: Color = Color(0.75, 0.2, 0.2, 0.35)
const BOSS_COLOR: Color = Color(1.0, 0.55, 0.1, 1.0)

var _player: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = -1  # behind the readouts, so it never sits on top of the counter


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not GameState.is_run_active:
		return
	var view: Vector2 = size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	var rect: Rect2 = Rect2(Vector2(EDGE_PAD, EDGE_PAD), view - Vector2(EDGE_PAD, EDGE_PAD) * 2.0)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var e: Node2D = enemy as Node2D
		# Canvas position already accounts for the camera and the 640x360 stretch.
		var screen_pos: Vector2 = e.get_global_transform_with_canvas().origin
		if rect.has_point(screen_pos):
			continue  # visible; the enemy speaks for itself
		_draw_marker(screen_pos, view, e)


func _draw_marker(screen_pos: Vector2, view: Vector2, enemy: Node2D) -> void:
	var centre: Vector2 = view * 0.5
	var to_enemy: Vector2 = screen_pos - centre
	if to_enemy.length() < 0.001:
		return
	var dir: Vector2 = to_enemy.normalized()

	# Push the direction out to the screen edge, then pull it back by the inset.
	var half: Vector2 = view * 0.5 - Vector2(MARKER_INSET, MARKER_INSET)
	var scale_x: float = half.x / maxf(absf(dir.x), 0.0001)
	var scale_y: float = half.y / maxf(absf(dir.y), 0.0001)
	var tip: Vector2 = centre + dir * minf(scale_x, scale_y)

	var colour: Color = BOSS_COLOR if enemy is BossEnemy else _distance_colour(enemy)

	# A triangle pointing the way you would have to travel.
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var base: Vector2 = tip - dir * (MARKER_SIZE * 1.6)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			base + perp * MARKER_SIZE,
			base - perp * MARKER_SIZE,
		]),
		colour
	)


func _distance_colour(enemy: Node2D) -> Color:
	"""Fade with distance so a far-off straggler does not shout as loudly as something
	about to walk into you."""
	if _player == null or not is_instance_valid(_player):
		return NEAR_COLOR
	var d: float = _player.global_position.distance_to(enemy.global_position)
	return NEAR_COLOR.lerp(FAR_COLOR, clampf(d / FAR_DISTANCE, 0.0, 1.0))
