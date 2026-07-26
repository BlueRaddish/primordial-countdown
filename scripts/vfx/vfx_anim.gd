# vfx_anim.gd
# Plays one frame-animated effect from a grid spritesheet, then frees itself.
#
# This is the real answer to "the skills don't look animated". Everything before it was
# a single texture being scaled and faded — which reads as a flash, not as an effect
# with frames. These are hand-drawn pixel animations (CodeManu's Free Pixel Effects
# Pack and tbbk's sword slash, both CC0), so a skill going off now has motion of its
# own instead of borrowing the tween.
#
# Draws the source rect directly rather than building a SpriteFrames resource at
# runtime: the sheets are plain grids, so a rect per frame is all it takes, and it
# keeps every effect a single self-freeing node with no resource churn.
#
# Can FOLLOW a node, which is what lets the melee slash sit on top of the character
# and travel with them instead of being stamped on the world where the swing started.
extends Node2D

var sheet: Texture2D = null
var frame_size: Vector2i = Vector2i(100, 100)
var frames: int = 60
var fps: float = 60.0
# Width in world pixels the effect is drawn at. The sheets are 100px art for a 640x360
# game, so nearly everything needs scaling down.
var draw_width: float = 40.0
var color: Color = Color.WHITE
var flip_h: bool = false
var angle: float = 0.0
# Follow a node so an effect can ride the character that produced it.
var follow: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO
# Additive reads as light — right for magic and sparks, wrong for smoke and dust.
var additive: bool = true

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = 9 # Over the hitbox fills (4) and the particle sprites (8).
	if additive:
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _process(delta: float) -> void:
	_elapsed += delta
	if fps <= 0.0 or sheet == null or _elapsed * fps >= float(frames):
		queue_free()
		return
	if is_instance_valid(follow):
		global_position = follow.global_position + follow_offset
	queue_redraw()


func _draw() -> void:
	if sheet == null:
		return
	var index: int = clampi(int(_elapsed * fps), 0, frames - 1)
	var cols: int = maxi(int(sheet.get_width() / frame_size.x), 1)
	var src: Rect2 = Rect2(
		Vector2(float((index % cols) * frame_size.x), float((index / cols) * frame_size.y)),
		Vector2(frame_size)
	)

	var aspect: float = float(frame_size.y) / float(frame_size.x)
	var w: float = draw_width
	var h: float = draw_width * aspect
	var dest: Rect2 = Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))

	draw_set_transform(Vector2.ZERO, angle, Vector2(-1.0 if flip_h else 1.0, 1.0))
	draw_texture_rect_region(sheet, dest, src, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
