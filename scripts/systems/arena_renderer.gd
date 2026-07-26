# arena_renderer.gd
# Builds the arena: ground, side walls, and a set of layered platforms.
# Draws the tiles and generates the matching StaticBody2D colliders, so the layout
# lives in one place instead of being split between script and scene.
#
# Platform spacing is sized against the player's actual jump arc:
#
#   intact legs:  jump_force = -330  ->  peak rise 330^2 / (2*800) = 68 px
#   partial legs: jump_force = -264  ->  peak rise 264^2 / (2*800) = 44 px
#                 and move speed drops to 78 px/s
#
# At a 27 px rise with partial legs the player is above the ledge for ~0.41 s,
# carrying ~32 px horizontally. So the MAIN ROUTE uses 27 px steps and gaps of
# 18 px, which stays climbable on degraded legs.
#
# The HIGH ROUTE uses 45 px steps, which partial legs (44 px peak) cannot make.
# That is deliberate: losing a trait should close off parts of the arena.
extends Node2D

const TILE_SIZE: int = 18
const GROUND_Y: float = 288.0
const TERRAIN_LAYER: int = 3 # project.godot: 2d_physics/layer_3 = "terrain"

# One-way platforms get a thin collider pinned to their top surface rather than a
# full-height one. A thick one-way box lets the player end up inside it on the way
# up and pop out at the wrong edge, which is what made the platforms feel wrong.
const ONE_WAY_THICKNESS: float = 8.0
# Must exceed the worst-case distance the player can fall in a single physics frame,
# or a fast fall passes straight through the thin collider between two frames.
# At player.gd's max_fall_speed of 400 px/s and the project's 60 physics ticks/s
# that is 400/60 = 6.67 px — the old margin of 6.0 was already below it, so any
# landing at or near terminal velocity could tunnel. 16 clears it with enough
# headroom to survive a dropped frame (two frames at terminal velocity = 13.3 px).
const ONE_WAY_MARGIN: float = 16.0

@export var ground_top_texture: Texture2D
@export var ground_fill_texture: Texture2D
@export var arena_width_tiles: int = 60
@export var floor_depth_tiles: int = 4
@export var wall_height: float = 320.0

# Platform surfaces in world pixels: Rect2(x, top_y, width, height).
#
# MAIN ROUTE (indices 0-7): 27 px steps, 18 px gaps. Climbs left to right to the
# summit at y=153, then descends the right-hand side back to the ground.
#
# HIGH ROUTE (indices 8-10): 45 px steps above the summit. Intact legs only.
@export var platforms: Array[Rect2] = [
	Rect2(126, 261, 90, 18),   # 0: first step up off the ground
	Rect2(234, 234, 90, 18),   # 1: one-way — drop through to restart the climb
	Rect2(342, 207, 108, 18),  # 2: mid shelf
	Rect2(468, 180, 90, 18),   # 3: one-way
	Rect2(576, 153, 108, 18),  # 4: summit of the main route
	Rect2(720, 180, 90, 18),   # 5: descending the right side
	Rect2(846, 207, 90, 18),   # 6: one-way
	Rect2(972, 234, 72, 18),   # 7: last step down to the ground
	Rect2(612, 108, 54, 18),   # 8: HIGH — 45 px above the summit
	Rect2(504, 63, 54, 18),    # 9: HIGH — one-way, top of the arena
	Rect2(378, 99, 54, 18),    # 10: HIGH — descent perch on the far left
]

# Indices into `platforms` that the player can jump up through from below.
@export var one_way_platforms: Array[int] = [1, 3, 6, 9]


func _ready() -> void:
	add_to_group("arena")
	_build_colliders()
	queue_redraw()


# ---- Public API ----

func get_arena_width() -> float:
	return float(arena_width_tiles * TILE_SIZE)


func get_ground_spawn_points(count: int) -> PackedVector2Array:
	"""Evenly spread points along the ground, inset from the walls."""
	var points: PackedVector2Array = PackedVector2Array()
	if count <= 0:
		return points
	var width: float = get_arena_width()
	var margin: float = 60.0
	for i: int in range(count):
		var t: float = float(i + 1) / float(count + 1)
		points.append(Vector2(margin + t * (width - margin * 2.0), GROUND_Y))
	return points


func get_platform_spawn_points() -> PackedVector2Array:
	"""One spawn point centred on each platform surface."""
	var points: PackedVector2Array = PackedVector2Array()
	for rect: Rect2 in platforms:
		points.append(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y))
	return points


# ---- Collider generation ----

func _build_colliders() -> void:
	var width: float = get_arena_width()
	var floor_depth: float = float(floor_depth_tiles * TILE_SIZE)

	# Ground slab.
	_make_body(
		"Ground",
		Vector2(width * 0.5, GROUND_Y + floor_depth * 0.5),
		Vector2(width, floor_depth),
		false
	)

	# Side walls, so the player cannot simply walk out of the arena.
	_make_body(
		"WallLeft",
		Vector2(-TILE_SIZE * 0.5, GROUND_Y - wall_height * 0.5),
		Vector2(float(TILE_SIZE), wall_height),
		false
	)
	_make_body(
		"WallRight",
		Vector2(width + TILE_SIZE * 0.5, GROUND_Y - wall_height * 0.5),
		Vector2(float(TILE_SIZE), wall_height),
		false
	)

	# Platforms.
	for i: int in range(platforms.size()):
		var rect: Rect2 = platforms[i]
		if one_way_platforms.has(i):
			# Thin collider sitting on the top surface only, so the player passes
			# cleanly through the body of the platform on the way up.
			_make_body(
				"Platform%d" % i,
				Vector2(
					rect.position.x + rect.size.x * 0.5,
					rect.position.y + ONE_WAY_THICKNESS * 0.5
				),
				Vector2(rect.size.x, ONE_WAY_THICKNESS),
				true
			)
		else:
			_make_body(
				"Platform%d" % i,
				rect.position + rect.size * 0.5,
				rect.size,
				false
			)


func _make_body(node_name: String, center: Vector2, size: Vector2, one_way: bool) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(TERRAIN_LAYER, true)

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	shape_node.shape = rect_shape
	shape_node.one_way_collision = one_way
	if one_way:
		# Margin has to exceed the per-frame fall distance or fast falls tunnel
		# straight through the thin collider.
		shape_node.one_way_collision_margin = ONE_WAY_MARGIN
	body.add_child(shape_node)

	add_child(body)


# ---- Drawing ----

func _draw() -> void:
	if not ground_top_texture or not ground_fill_texture:
		return

	# Ground: one row of top tiles, fill rows beneath.
	for x: int in range(arena_width_tiles):
		draw_texture(ground_top_texture, Vector2(float(x * TILE_SIZE), GROUND_Y))
	for y: int in range(1, floor_depth_tiles):
		for x: int in range(arena_width_tiles):
			draw_texture(
				ground_fill_texture,
				Vector2(float(x * TILE_SIZE), GROUND_Y + float(y * TILE_SIZE))
			)

	# Platforms: top tiles across the surface, fill for any depth below.
	for i: int in range(platforms.size()):
		var rect: Rect2 = platforms[i]
		var cols: int = maxi(1, int(round(rect.size.x / float(TILE_SIZE))))
		var rows: int = maxi(1, int(round(rect.size.y / float(TILE_SIZE))))
		for cx: int in range(cols):
			for cy: int in range(rows):
				var pos: Vector2 = rect.position + Vector2(
					float(cx * TILE_SIZE), float(cy * TILE_SIZE)
				)
				var tex: Texture2D = ground_top_texture if cy == 0 else ground_fill_texture
				draw_texture(tex, pos)

		# Mark one-way platforms with a thin highlight so testers can see which
		# ones they can jump up through.
		if one_way_platforms.has(i):
			draw_line(
				rect.position + Vector2(0.0, -1.0),
				rect.position + Vector2(rect.size.x, -1.0),
				Color(0.4, 0.9, 0.85, 0.6),
				1.0
			)
