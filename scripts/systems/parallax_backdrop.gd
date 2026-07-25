# parallax_backdrop.gd
# Scrolling backdrop behind the arena, built from the volcano pack's separated layers.
#
# This deliberately does NOT use ParallaxBackground. That node makes its own
# CanvasLayer, and a CanvasModulate only tints the layer it belongs to — so the
# Eyes trait, which dims the world through the CanvasModulate on Arena, would have
# left the sky at full brightness while everything else went dark. Living inside
# Arena as a plain Node2D means these layers dim along with the rest of the world.
#
# The pack ships its layers as pieces of one 1280x720 painting rather than as
# free-floating strips, so each has a fixed place on that canvas: five are
# bottom-aligned but the cloud band is anchored to the top. `layer_offset_y`
# carries those positions, recovered by matching each layer against the pack's
# own composed bg_volcano.png. The canvas is then hung so its bottom edge sits at
# `horizon_y`, and scrolls horizontally against the camera. Vertical position is
# fixed in world space, so climbing to the summit reveals more sky.
extends Node2D

# One texture per layer, ordered back to front.
@export var layer_textures: Array[Texture2D] = []

# Each layer's y position on the source canvas, matched by index to
# `layer_textures`. Layers missing an entry are bottom-aligned.
@export var layer_offset_y: Array[float] = []

# Height of the canvas those offsets are measured against.
@export var canvas_height: float = 720.0

# Parallax rate per layer, matched by index to `layer_textures`.
#   0.0 = pinned to the camera, i.e. infinitely far away
#   1.0 = fixed in the world, i.e. no parallax at all
# Layers missing an entry here fall back to `default_scroll`.
@export var layer_scroll: Array[float] = []
@export var default_scroll: float = 0.25

# Where the bottom edge of the source canvas sits in world space. This is well
# below ArenaRenderer.GROUND_Y (288) on purpose: the painting puts its peaks in
# the middle of a 720px frame, and the game only shows 360px at a time, so
# hanging the canvas by its bottom edge at the ground line left everything
# interesting above the top of the screen. Dropping it to 470 pushes the peaks
# down into view and tucks the dark foreground ridge behind the ground tiles.
@export var horizon_y: float = 470.0

# Horizontal anchor. The layers are 1280px wide and the camera sweeps roughly
# -30..1110 across the arena, which is what bounds this and the scroll rates:
# a layer must still cover the 640px-wide view at both ends of that sweep.
# Solving  cam*(1-f) + base <= cam - 320  and  cam*(1-f) + base + 1280 >= cam + 320
# for the full camera range gives f <= 0.56 and base in [-405, -335] at f = 0.5.
@export var base_x: float = -370.0

var _layers: Array[Sprite2D] = []


func _ready() -> void:
	for i: int in layer_textures.size():
		var tex: Texture2D = layer_textures[i]
		if tex == null:
			continue
		var layer: Sprite2D = Sprite2D.new()
		layer.texture = tex
		layer.centered = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var offset_y: float = canvas_height - float(tex.get_height())
		if i < layer_offset_y.size():
			offset_y = layer_offset_y[i]
		layer.position = Vector2(base_x, horizon_y - canvas_height + offset_y)
		add_child(layer)
		_layers.append(layer)
	_update_layers()


func _process(_delta: float) -> void:
	_update_layers()


func _update_layers() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var camera_x: float = camera.global_position.x
	for i: int in _layers.size():
		var scroll: float = default_scroll
		if i < layer_scroll.size():
			scroll = layer_scroll[i]
		_layers[i].position.x = camera_x * (1.0 - scroll) + base_x
