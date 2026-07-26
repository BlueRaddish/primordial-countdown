# parallax_backdrop.gd
# Scrolling backdrop behind the arena, tiled from a set of seamless-loop layer strips.
#
# This deliberately does NOT use ParallaxBackground. That node makes its own
# CanvasLayer, and a CanvasModulate only tints the layer it belongs to — so the
# Eyes trait, which dims the world through the CanvasModulate on Arena, would have
# left the sky at full brightness while everything else went dark. Living inside
# Arena as a plain Node2D means these layers dim along with the rest of the world.
#
# TILING. Every era pack (swamp/town/cyberpunk, all ansimuz) ships each layer as a
# small seamless-loop strip — as narrow as 96px — meant to repeat edge to edge, not
# as one fixed painting the way the old volcano pack was. So each layer gets several
# Sprite2D copies side by side, and every frame all copies are repositioned so the
# leftmost one always starts at or before the camera's left edge: cheap (a handful of
# extra Sprite2D nodes) and immune to camera direction changes, since there's no
# recycling state to get out of sync — position is recomputed fresh every frame.
extends Node2D

# One texture per layer, ordered back to front.
@export var layer_textures: Array[Texture2D] = []

# Each layer's y position on the source canvas, matched by index to
# `layer_textures`. Layers missing an entry are bottom-aligned.
@export var layer_offset_y: Array[float] = []

# Height of the canvas those offsets are measured against. For a pack whose layers
# are each a complete, independent image (as opposed to slices of one shared
# painting), set this to that image's own height — offset_y then defaults to 0 and
# every layer's bottom edge lands on `horizon_y`.
@export var canvas_height: float = 720.0

# Parallax rate per layer, matched by index to `layer_textures`.
#   0.0 = pinned to the camera, i.e. infinitely far away
#   1.0 = fixed in the world, i.e. no parallax at all
# Layers missing an entry here fall back to `default_scroll`.
@export var layer_scroll: Array[float] = []
@export var default_scroll: float = 0.25

# Where the bottom edge of the source canvas sits in world space.
@export var horizon_y: float = 470.0

# Extra per-layer horizontal phase offset. With tiling there is no fixed-width
# canvas to line up against a camera sweep, so this is just a nudge for variety —
# 0.0 is a perfectly good default.
@export var base_x: float = 0.0

# Half the base viewport width (project.godot is 640x360; canvas_items stretch keeps
# 2D coordinates in that space regardless of window scaling). Used to size and place
# enough tile copies to always cover the screen.
const VIEWPORT_HALF_WIDTH: float = 320.0
# Extra tile on each side so a fast camera pan never uncovers a gap before the next
# _process call repositions everything.
const TILE_MARGIN: int = 1

var _layer_tiles: Array[Array] = [] # Array[Array[Sprite2D]], matched by layer index
var _layer_tile_width: Array[float] = []


func _ready() -> void:
	add_to_group("parallax_backdrop")
	_build_tiles()
	_update_layers()


func _process(_delta: float) -> void:
	_update_layers()


# Tears down the current tile set and rebuilds it from `layer_textures`/`layer_offset_y`/
# `canvas_height`/`horizon_y` as they currently stand. Called once from `_ready()`; also
# the second half of `set_layers()` below, so an era swap gets exactly the same tile setup
# a fresh scene load would.
func _build_tiles() -> void:
	for tiles: Array in _layer_tiles:
		for t: Sprite2D in tiles:
			t.queue_free()
	_layer_tiles.clear()
	_layer_tile_width.clear()

	for i: int in layer_textures.size():
		var tex: Texture2D = layer_textures[i]
		var tiles: Array = []
		var tile_width: float = 0.0
		if tex != null:
			tile_width = float(tex.get_width())
			var offset_y: float = canvas_height - float(tex.get_height())
			if i < layer_offset_y.size():
				offset_y = layer_offset_y[i]
			var y: float = horizon_y - canvas_height + offset_y
			var needed: int = ceili(VIEWPORT_HALF_WIDTH * 2.0 / tile_width) + 1 + TILE_MARGIN * 2
			for _j: int in needed:
				var tile: Sprite2D = Sprite2D.new()
				tile.texture = tex
				tile.centered = false
				tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tile.position.y = y
				add_child(tile)
				tiles.append(tile)
		_layer_tiles.append(tiles)
		_layer_tile_width.append(tile_width)


# Swaps in a new era's layers at runtime — same shape `layer_textures`/`layer_offset_y`/
# `canvas_height`/`horizon_y`/`layer_scroll` already have as exports, just settable after
# `_ready()` instead of only being read once. Used by stage_manager.gd on an era
# transition; game.tscn's own authored values are era 1's, so this is never called for
# the run's starting era.
func set_layers(
	textures: Array[Texture2D],
	offsets: Array[float],
	scroll: Array[float],
	new_canvas_height: float,
	new_horizon_y: float
) -> void:
	layer_textures = textures
	layer_offset_y = offsets
	layer_scroll = scroll
	canvas_height = new_canvas_height
	horizon_y = new_horizon_y
	_build_tiles()
	_update_layers()


func _update_layers() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var camera_x: float = camera.global_position.x
	for i: int in _layer_tiles.size():
		var w: float = _layer_tile_width[i]
		if w <= 0.0:
			continue
		var scroll: float = default_scroll
		if i < layer_scroll.size():
			scroll = layer_scroll[i]
		# Same parallax formula the single-sprite version used: this is the world-x
		# that this layer's local origin (tile index 0) maps to.
		var parallax_x: float = camera_x * (1.0 - scroll) + base_x
		# Leftmost tile index whose span can still reach the camera's left edge,
		# with one extra tile of margin so nothing pops in at the screen edge.
		var left_edge: float = camera_x - VIEWPORT_HALF_WIDTH
		var base_index: int = floori((left_edge - parallax_x) / w) - TILE_MARGIN
		var tiles: Array = _layer_tiles[i]
		for j: int in tiles.size():
			(tiles[j] as Sprite2D).position.x = parallax_x + float(base_index + j) * w
