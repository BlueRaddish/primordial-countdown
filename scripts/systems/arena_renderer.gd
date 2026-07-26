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
# or a fast fall passes straight through the thin collider between two frames. At
# player.gd's max_fall_speed of 400 px/s and 60 physics ticks/s that is 6.67 px — the
# original 6.0 was below it, so any landing near terminal velocity could tunnel.
#
# But the margin cuts both ways: it extends the blocking band this far BELOW the
# surface, and anything whose head is inside that band gets caught on a platform it
# is walking under. At 16 that band was 16px deep, which trapped enemies beneath the
# lowest shelf. 12 keeps ~1.8x headroom over the tunnelling threshold while leaving
# room to walk under the shelves — see the clearance note on platform 0 below.
const ONE_WAY_MARGIN: float = 12.0
# Height of a player/enemy collider. The blocking band must not reach down into the
# space a body needs in order to walk underneath a shelf.
const BODY_HEIGHT: float = 20.0
# Below this the margin stops being useful, so a platform with no room simply gets a
# small one and accepts the occasional fall-through.
const ONE_WAY_MARGIN_MIN: float = 6.0

@export var ground_top_texture: Texture2D
@export var ground_fill_texture: Texture2D
@export var arena_width_tiles: int = 60
@export var floor_depth_tiles: int = 4
# Side walls are OFF by default. They spanned the full playable height, so any aerial
# line that reached the edge of the arena stopped dead against nothing visible — the
# worst kind of boundary, because the player cannot see what stopped them. With wings,
# a dash and a glide in the kit, the edges are where the interesting movement happens.
#
# The trade is that the arena now ends in open air: leaving it means falling into the
# death zone. That is a real risk and it is meant to be. Set this above 0 to put the
# walls back — the build code is unchanged, it simply skips a zero height.
@export var wall_height: float = 0.0

# Platform surfaces in world pixels: Rect2(x, top_y, width, height).
#
# MAIN ROUTE (indices 0-7): 27 px steps, 18 px gaps. Climbs left to right to the
# summit at y=153, then descends the right-hand side back to the ground.
#
# HIGH ROUTE (indices 8-10): 45 px steps above the summit. Intact legs only.
@export var platforms: Array[Rect2] = [
	# 0: first step up off the ground. Raised from y=261 to clear the space beneath
	# it: a body is 20px tall and the one-way margin blocks 12px below the surface,
	# so the underside needs 32px of headroom over the ground at y=288 or anything
	# walking under gets caught. 288-252 = 36px clears it, and a 36px step is still
	# well inside partial legs' 44px jump.
	Rect2(126, 252, 90, 18),   # 0: first step up off the ground
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

	# OPTIONAL ROUTES (11+). Appended rather than folded into the staircase above,
	# because 0-10 are sized against the jump arc in this file's header and rebuilding
	# them risks the one property that must hold: the main route stays climbable on
	# partial legs, the high route does not.
	#
	# These are all skippable. They exist to stop the arena reading as a single
	# left-to-right staircase, and to give the air something to aim at.
	Rect2(36, 252, 54, 18),    # 11: low perch left of the staircase's first step
	Rect2(450, 153, 45, 18),   # 12: island over the 2->3 gap. 54px above platform 2,
	                           #     so intact legs only — a shortcut, not a route.
	Rect2(792, 126, 45, 18),   # 13: perch above the right-hand descent, same rule

	# OUTBOARD (14-15) — beyond the arena floor, over open air. Only reachable now the
	# side walls are gone, and standing on one means a fall kills you rather than a wall
	# catching you. This is the risk half of removing the walls.
	Rect2(-90, 207, 54, 18),   # 14: left, past the edge of the ground
	Rect2(1116, 216, 54, 18),  # 15: right, past the edge of the ground
]

# Indices into `platforms` that the player can jump up through from below.
#
# EVERY floating platform is one-way. Only the ground and the side walls are solid.
# Two bugs came from having a mixed set:
#
#   * Solid platforms blocked jumps from underneath, so half the shelves could not be
#     reached the way the other half could — the arena read as inconsistent rather
#     than as a route.
#   * Enemies got wedged under platform 0. Its underside sits at y=279 and the ground
#     at y=288, a 9px gap; an enemy is 20px tall, so anything that walked in there was
#     stuck against a solid box it could not pass. A one-way collider only stops a
#     body falling onto it from above, so the same enemy now simply walks through.
#
# Kept as an export rather than hardcoded so a future arena can still opt a platform
# out — but the default is "all of them", and a solid floating platform should be a
# deliberate decision with a reason next to it.
@export var one_way_platforms: Array[int] = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
]


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

	# Side walls, only if a height is set. See the export for why they default to off.
	if wall_height > 0.0:
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
				true,
				_one_way_margin_for(rect)
			)
		else:
			_make_body(
				"Platform%d" % i,
				rect.position + rect.size * 0.5,
				rect.size,
				false
			)


func _one_way_margin_for(rect: Rect2) -> float:
	"""How deep this platform's blocking band may reach without trapping bodies that
	walk beneath it.

	`one_way_collision_margin` extends downward from the collider's BOTTOM edge, so a
	generous margin on a low shelf swallows the gap underneath it — which is what
	wedged enemies below platform 0 (27px of headroom, against a 20px body and a 16px
	margin). Deep platforms keep the full margin; shallow ones get only what fits, and
	take an occasional fall-through instead. That is the right trade: falling through
	the lowest shelf drops you a few dozen pixels onto the ground, whereas a trapped
	enemy or an unclimbable route is a broken arena."""
	var clearance: float = GROUND_Y - (rect.position.y + ONE_WAY_THICKNESS)
	var usable: float = clearance - BODY_HEIGHT - 2.0
	return clampf(usable, ONE_WAY_MARGIN_MIN, ONE_WAY_MARGIN)


func _make_body(
	node_name: String,
	center: Vector2,
	size: Vector2,
	one_way: bool,
	one_way_margin: float = ONE_WAY_MARGIN
) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(TERRAIN_LAYER, true)
	if one_way:
		# Lets the player identify what it is standing on, so pressing down can drop
		# through a shelf without also dropping through the ground.
		body.add_to_group("one_way_platform")

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	shape_node.shape = rect_shape
	shape_node.one_way_collision = one_way
	if one_way:
		# Margin has to exceed the per-frame fall distance or fast falls tunnel
		# straight through the thin collider — but not so deep that it blocks the
		# space beneath. See _one_way_margin_for().
		shape_node.one_way_collision_margin = one_way_margin
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

		# A solid floating platform is now the exception, so it is the one worth
		# marking — a red underline means "this one will block your jump".
		if not one_way_platforms.has(i):
			draw_line(
				rect.position + Vector2(0.0, rect.size.y + 1.0),
				rect.position + Vector2(rect.size.x, rect.size.y + 1.0),
				Color(0.9, 0.35, 0.3, 0.6),
				1.0
			)
