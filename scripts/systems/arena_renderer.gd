# arena_renderer.gd
# Draws a flat arena floor using the Kenney tileset.
# Attach to the Arena node. Tiles the ground visually and places wall colliders.
extends Node2D

@export var ground_top_texture: Texture2D
@export var ground_fill_texture: Texture2D
@export var arena_width_tiles: int = 40
@export var floor_depth_tiles: int = 3

const TILE_SIZE := 18

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if not ground_top_texture or not ground_fill_texture:
		return

	# Draw top row of ground.
	for x in range(arena_width_tiles):
		var pos := Vector2(x * TILE_SIZE, 0)
		draw_texture(ground_top_texture, pos)

	# Draw fill rows below.
	for y in range(1, floor_depth_tiles):
		for x in range(arena_width_tiles):
			var pos := Vector2(x * TILE_SIZE, y * TILE_SIZE)
			draw_texture(ground_fill_texture, pos)
