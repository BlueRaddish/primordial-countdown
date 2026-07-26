# vfx_sprite.gd
# One-shot textured effect: draws a texture that scales, spins, drifts and fades over
# a short lifetime, then frees itself.
#
# Art is the Kenney Particle Pack (CC0) in assets/sprites/vfx. Real textures rather
# than drawn shapes because everything in this game previously spawned the SAME fading
# translucent circle — a landed hit, a buff, a dash and a boss slam were visually
# identical, which is a problem in a game whose entire combat contract is "read what is
# about to happen".
#
# Anything that has to match a live gameplay NUMBER (a hitbox rect, a strike radius)
# stays procedural instead — see vfx_hitbox.gd and vfx_telegraph.gd. A texture cannot
# track a radius that gets retuned; a drawn shape can.
#
# Deliberately no `class_name`: consumers preload it, because a newly declared global
# class is invisible to headless runs until the editor rescans.
extends Node2D

var texture: Texture2D = null
var color: Color = Color.WHITE
var lifetime: float = 0.28
# Size in world pixels at the widest point of the effect.
var start_size: float = 16.0
var end_size: float = 26.0
var start_angle: float = 0.0
var spin: float = 0.0
# Constant drift, e.g. dust rising or sparks carrying the way the hit went.
var velocity: Vector2 = Vector2.ZERO
var drag: float = 3.0
var start_alpha: float = 0.9
# Additive reads as light (sparks, flashes); normal reads as matter (smoke, dust).
var additive: bool = true
# 0 = fade steadily, higher = hold bright then drop away fast.
var fade_curve: float = 1.6

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = 8 # Above hitbox fills, the sweep trail and the sprites themselves.
	if additive:
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime or texture == null:
		queue_free()
		return
	velocity = velocity.move_toward(Vector2.ZERO, drag * 60.0 * delta)
	position += velocity * delta
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var t: float = clampf(_elapsed / lifetime, 0.0, 1.0)
	var size: float = lerpf(start_size, end_size, ease(t, 0.4))
	var alpha: float = start_alpha * (1.0 - ease(t, fade_curve))

	var tint: Color = color
	tint.a = alpha

	# Drawn about its own centre so scaling and spin stay anchored on the hit point.
	draw_set_transform(Vector2.ZERO, start_angle + spin * t, Vector2.ONE)
	draw_texture_rect(
		texture,
		Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)),
		false,
		tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
