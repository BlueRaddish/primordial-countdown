# vfx.gd
# Every visual effect in the game, behind one named call each.
#
# Before this, gameplay code spawned AoEIndicator directly and tuned colours/radii
# inline, which meant a landed hit, a buff, a dash and a boss slam all produced the
# same fading circle. Naming the effects — `impact`, `slash`, `cast`, `slam` — puts the
# decision "what does this read as" in one place, and stops the call sites carrying
# presentation detail.
#
# TWO KINDS OF EFFECT, on purpose:
#   * Sprites (Kenney Particle Pack, CC0) for the flourish — sparks, slashes, smoke.
#   * Procedural for anything that must match a live gameplay number — the true
#     hitbox shape, an enemy's real strike radius. A texture cannot follow a value
#     that gets retuned; a drawn shape can.
#
# Layering is fixed so the two never fight: hitbox shapes at z 4, sprites at z 8. The
# animation always reads OVER the shape it belongs to.
#
# Preloaded rather than `class_name`: a newly declared global class is invisible to a
# headless run until the editor rescans.
extends RefCounted

const VfxSprite := preload("res://scripts/vfx/vfx_sprite.gd")
const VfxHitbox := preload("res://scripts/vfx/vfx_hitbox.gd")
const VfxTelegraph := preload("res://scripts/vfx/vfx_telegraph.gd")
const VfxAnim := preload("res://scripts/vfx/vfx_anim.gd")

# --- Frame animations (CodeManu Free Pixel Effects Pack + tbbk sword slash, both CC0)
#
# These are the actual animations. Everything else in this file scales and fades a
# single texture, which reads as a flash; these have frames of their own, which is what
# makes a skill look animated rather than lit up.
#
# `frames` is the count of NON-BLANK cells — the sheets pad their grids with empty
# cells, and playing those would leave the effect hanging invisibly on screen.
const ANIMS: Dictionary = {
	"slash": {
		"tex": preload("res://assets/sprites/vfx/pixel/slash_sword.png"),
		"fw": 64, "fh": 47, "frames": 9, "fps": 34.0,
	},
	"weaponhit": {
		"tex": preload("res://assets/sprites/vfx/pixel/weaponhit.png"),
		"fw": 100, "fh": 100, "frames": 31, "fps": 60.0,
	},
	"magickahit": {
		"tex": preload("res://assets/sprites/vfx/pixel/magickahit.png"),
		"fw": 100, "fh": 100, "frames": 41, "fps": 60.0,
	},
	"casting": {
		"tex": preload("res://assets/sprites/vfx/pixel/casting.png"),
		"fw": 100, "fh": 100, "frames": 73, "fps": 75.0,
	},
	"magicspell": {
		"tex": preload("res://assets/sprites/vfx/pixel/magicspell.png"),
		"fw": 100, "fh": 100, "frames": 75, "fps": 75.0,
	},
	"protection": {
		"tex": preload("res://assets/sprites/vfx/pixel/protectioncircle.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 60.0,
	},
	"firespin": {
		"tex": preload("res://assets/sprites/vfx/pixel/firespin.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 70.0,
	},
	"sunburn": {
		"tex": preload("res://assets/sprites/vfx/pixel/sunburn.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 60.0,
	},
	"freezing": {
		"tex": preload("res://assets/sprites/vfx/pixel/freezing.png"),
		"fw": 100, "fh": 100, "frames": 86, "fps": 80.0,
	},
	"flamelash": {
		"tex": preload("res://assets/sprites/vfx/pixel/flamelash.png"),
		"fw": 100, "fh": 100, "frames": 46, "fps": 65.0,
	},
	"vortex": {
		"tex": preload("res://assets/sprites/vfx/pixel/vortex.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 65.0,
	},
	"phantom": {
		"tex": preload("res://assets/sprites/vfx/pixel/phantom.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 65.0,
	},
	"midnight": {
		"tex": preload("res://assets/sprites/vfx/pixel/midnight.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 65.0,
	},
	"brightfire": {
		"tex": preload("res://assets/sprites/vfx/pixel/brightfire.png"),
		"fw": 100, "fh": 100, "frames": 61, "fps": 65.0,
	},
}

const TEX_SLASH: Texture2D = preload("res://assets/sprites/vfx/slash_01.png")
const TEX_SLASH_WIDE: Texture2D = preload("res://assets/sprites/vfx/slash_03.png")
const TEX_SPARK: Texture2D = preload("res://assets/sprites/vfx/spark_01.png")
const TEX_SPARK_SOFT: Texture2D = preload("res://assets/sprites/vfx/spark_04.png")
const TEX_SPARK_STAR: Texture2D = preload("res://assets/sprites/vfx/spark_06.png")
const TEX_MUZZLE: Texture2D = preload("res://assets/sprites/vfx/muzzle_02.png")
const TEX_MUZZLE_WIDE: Texture2D = preload("res://assets/sprites/vfx/muzzle_05.png")
const TEX_STAR: Texture2D = preload("res://assets/sprites/vfx/star_04.png")
const TEX_STAR_SOFT: Texture2D = preload("res://assets/sprites/vfx/star_08.png")
const TEX_MAGIC: Texture2D = preload("res://assets/sprites/vfx/magic_01.png")
const TEX_MAGIC_RING: Texture2D = preload("res://assets/sprites/vfx/magic_05.png")
const TEX_SMOKE: Texture2D = preload("res://assets/sprites/vfx/smoke_04.png")
const TEX_SMOKE_SOFT: Texture2D = preload("res://assets/sprites/vfx/smoke_08.png")
const TEX_DIRT: Texture2D = preload("res://assets/sprites/vfx/dirt_02.png")
const TEX_TRACE: Texture2D = preload("res://assets/sprites/vfx/trace_01.png")
const TEX_TRACE_SOFT: Texture2D = preload("res://assets/sprites/vfx/trace_06.png")
const TEX_GLOW: Texture2D = preload("res://assets/sprites/vfx/circle_05.png")
const TEX_LIGHT: Texture2D = preload("res://assets/sprites/vfx/light_02.png")
const TEX_FLARE: Texture2D = preload("res://assets/sprites/vfx/flare_01.png")
const TEX_SCORCH: Texture2D = preload("res://assets/sprites/vfx/scorch_02.png")
const TEX_TWIRL: Texture2D = preload("res://assets/sprites/vfx/twirl_02.png")
const TEX_SCRATCH: Texture2D = preload("res://assets/sprites/vfx/scratch_01.png")


# ---- Core spawners ----

static func sprite(parent: Node, pos: Vector2, tex: Texture2D) -> Node2D:
	"""Bare textured effect. Callers set size/colour/spin on the returned node."""
	if parent == null or tex == null:
		return null
	var fx: Node2D = VfxSprite.new()
	fx.set("texture", tex)
	parent.add_child(fx)
	fx.global_position = pos
	return fx


static func anim(
	parent: Node,
	pos: Vector2,
	id: String,
	width: float,
	tint: Color = Color.WHITE,
	rotation: float = 0.0
) -> Node2D:
	"""Play a frame animation by name. Unknown ids are a no-op rather than a crash, so
	a mistyped effect never takes gameplay down with it."""
	if parent == null or not ANIMS.has(id):
		return null
	var d: Dictionary = ANIMS[id]
	var fx: Node2D = VfxAnim.new()
	fx.set("sheet", d["tex"])
	fx.set("frame_size", Vector2i(d["fw"], d["fh"]))
	fx.set("frames", d["frames"])
	fx.set("fps", d["fps"])
	fx.set("draw_width", width)
	fx.set("color", tint)
	fx.set("angle", rotation)
	parent.add_child(fx)
	fx.global_position = pos
	return fx


static func hitbox(parent: Node, pos: Vector2) -> Node2D:
	"""The true hit shape, drawn solid. A debugging view — off unless the player asks
	for it in Settings, since with the effects animated the shapes are clutter. Callers
	must tolerate null, which they already do."""
	if parent == null or not GameState.show_hitboxes:
		return null
	var hb: Node2D = VfxHitbox.new()
	parent.add_child(hb)
	hb.global_position = pos
	return hb


# ---- Named effects ----

static func impact(parent: Node, pos: Vector2, dir: Vector2, tint: Color) -> void:
	"""Something connected. Sharp, brief, thrown along the direction of the blow."""
	# The animated hit sits on top; the shards below give it direction.
	anim(parent, pos, "weaponhit", 34.0, tint, dir.angle())

	var flash: Node2D = sprite(parent, pos, TEX_SPARK_STAR)
	if flash:
		flash.set("color", Color(1.0, 1.0, 1.0))
		flash.set("start_size", 6.0)
		flash.set("end_size", 20.0)
		flash.set("lifetime", 0.16)
		flash.set("fade_curve", 2.2)

	for i: int in range(3):
		var shard: Node2D = sprite(parent, pos, TEX_SPARK)
		if not shard:
			continue
		var spread: Vector2 = dir.rotated(randf_range(-0.8, 0.8)).normalized()
		shard.set("color", tint)
		shard.set("start_size", 10.0)
		shard.set("end_size", 3.0)
		shard.set("lifetime", randf_range(0.18, 0.30))
		shard.set("start_angle", spread.angle())
		shard.set("velocity", spread * randf_range(90.0, 170.0))


static func slash(
	parent: Node,
	pos: Vector2,
	angle: float,
	reach: float,
	tint: Color,
	rider: Node2D = null
) -> void:
	"""A melee swing: a real frame-animated slash, laid over the character.

	Passing `rider` makes it FOLLOW that node, which is the point — a swing stamped on
	the world where it started detaches from the body the moment the player moves, and
	at 120px/s that is immediately. Riding the character keeps the swing attached to
	the thing swinging it."""
	var arc: Node2D = anim(parent, pos, "slash", reach * 2.0, tint, angle)
	if arc and rider:
		arc.set("follow", rider)
		# Held out along the aim so the blade reads as leaving the body, not bisecting it.
		arc.set("follow_offset", Vector2(0.0, -10.0) + Vector2.RIGHT.rotated(angle) * reach * 0.45)


static func cast(parent: Node, pos: Vector2, tint: Color, reach: float) -> void:
	"""A skill going off on the player — the 'this fired' punctuation."""
	var burst: Node2D = sprite(parent, pos, TEX_MUZZLE_WIDE)
	if burst:
		burst.set("color", tint)
		burst.set("start_size", reach * 0.7)
		burst.set("end_size", reach * 1.9)
		burst.set("lifetime", 0.26)
		burst.set("start_angle", randf() * TAU)

	var ring: Node2D = sprite(parent, pos, TEX_MAGIC_RING)
	if ring:
		ring.set("color", tint)
		ring.set("start_size", reach * 0.4)
		ring.set("end_size", reach * 2.3)
		ring.set("lifetime", 0.34)
		ring.set("start_alpha", 0.7)


static func aoe(parent: Node, pos: Vector2, tint: Color, reach: float) -> void:
	"""An offensive skill's area, drawn over the solid hitbox that decides the hit."""
	var hb: Node2D = hitbox(parent, pos)
	if hb:
		hb.set("color", tint)
		hb.set("radius", reach)
		hb.set("lifetime", 0.24)

	var flare: Node2D = sprite(parent, pos, TEX_MUZZLE)
	if flare:
		flare.set("color", tint)
		flare.set("start_size", reach * 0.8)
		flare.set("end_size", reach * 2.0)
		flare.set("lifetime", 0.24)
		flare.set("start_angle", randf() * TAU)


static func buff(parent: Node, pos: Vector2, tint: Color) -> void:
	"""A self-buff landing. Rises, so it reads as gained rather than inflicted."""
	for i: int in range(4):
		var mote: Node2D = sprite(parent, pos + Vector2(randf_range(-8, 8), 0.0), TEX_STAR_SOFT)
		if not mote:
			continue
		mote.set("color", tint)
		mote.set("start_size", 10.0)
		mote.set("end_size", 3.0)
		mote.set("lifetime", randf_range(0.4, 0.65))
		mote.set("velocity", Vector2(randf_range(-14, 14), randf_range(-52, -30)))
		mote.set("drag", 0.6)


static func dash_trail(parent: Node, pos: Vector2, dir: Vector2, tint: Color) -> void:
	var streak: Node2D = sprite(parent, pos, TEX_TRACE)
	if streak:
		streak.set("color", tint)
		streak.set("start_size", 30.0)
		streak.set("end_size", 44.0)
		streak.set("lifetime", 0.22)
		streak.set("start_angle", dir.angle())
		streak.set("start_alpha", 0.75)


static func dust(parent: Node, pos: Vector2, amount: float) -> void:
	"""Landing / footfall. Normal blend — this is matter, not light."""
	var count: int = clampi(int(amount * 3.0) + 1, 1, 5)
	for i: int in range(count):
		var puff: Node2D = sprite(parent, pos + Vector2(randf_range(-6, 6), 0.0), TEX_DIRT)
		if not puff:
			continue
		puff.set("additive", false)
		puff.set("color", Color(0.75, 0.7, 0.62))
		puff.set("start_size", 6.0)
		puff.set("end_size", 16.0 + amount * 6.0)
		puff.set("lifetime", randf_range(0.3, 0.45))
		puff.set("velocity", Vector2(randf_range(-34, 34), randf_range(-20, -6)))
		puff.set("start_alpha", 0.5)


static func slam(parent: Node, pos: Vector2, reach: float, tint: Color) -> void:
	"""The boss's ground slam: a scorch on the floor, then the shock going outward."""
	# Drawn at the true blast radius, so the animation and the danger agree.
	anim(parent, pos, "sunburn", reach * 2.0, tint)

	var mark: Node2D = sprite(parent, pos, TEX_SCORCH)
	if mark:
		mark.set("additive", false)
		mark.set("color", Color(0.15, 0.08, 0.08))
		mark.set("start_size", reach * 1.1)
		mark.set("end_size", reach * 1.3)
		mark.set("lifetime", 0.7)
		mark.set("start_alpha", 0.55)
		mark.set("fade_curve", 0.8)

	var shock: Node2D = sprite(parent, pos, TEX_MAGIC_RING)
	if shock:
		shock.set("color", tint)
		shock.set("start_size", reach * 0.3)
		shock.set("end_size", reach * 2.2)
		shock.set("lifetime", 0.4)

	for i: int in range(5):
		var chunk: Node2D = sprite(parent, pos, TEX_DIRT)
		if not chunk:
			continue
		chunk.set("additive", false)
		chunk.set("color", Color(0.6, 0.52, 0.45))
		chunk.set("start_size", 8.0)
		chunk.set("end_size", 3.0)
		chunk.set("lifetime", randf_range(0.35, 0.55))
		chunk.set("velocity", Vector2(randf_range(-150, 150), randf_range(-130, -60)))
		chunk.set("drag", 1.2)


static func death(parent: Node, pos: Vector2, tint: Color) -> void:
	anim(parent, pos, "phantom", 44.0, tint)

	var pop: Node2D = sprite(parent, pos, TEX_STAR)
	if pop:
		pop.set("color", tint)
		pop.set("start_size", 10.0)
		pop.set("end_size", 34.0)
		pop.set("lifetime", 0.3)

	for i: int in range(3):
		var wisp: Node2D = sprite(parent, pos, TEX_SMOKE_SOFT)
		if not wisp:
			continue
		wisp.set("additive", false)
		wisp.set("color", Color(0.4, 0.36, 0.4))
		wisp.set("start_size", 12.0)
		wisp.set("end_size", 26.0)
		wisp.set("lifetime", randf_range(0.45, 0.7))
		wisp.set("velocity", Vector2(randf_range(-24, 24), randf_range(-40, -16)))
		wisp.set("start_alpha", 0.5)


static func telegraph(parent: Node, enemy: Node2D, reach: float, seconds: float) -> Node2D:
	"""An enemy committing to a strike. Returns the node so it can be cancelled when
	the windup is interrupted."""
	if parent == null or enemy == null:
		return null
	var tg: Node2D = VfxTelegraph.new()
	tg.set("radius", reach)
	tg.set("duration", seconds)
	tg.set("follow", enemy)
	parent.add_child(tg)
	tg.global_position = enemy.global_position
	return tg


static func enemy_strike(parent: Node, pos: Vector2, reach: float, aim: Vector2) -> void:
	"""The strike actually landing — shown at the true radius so what you see is what
	could have hit you."""
	var hb: Node2D = hitbox(parent, pos)
	if hb:
		hb.set("color", Color("e74c3c"))
		hb.set("radius", reach)
		hb.set("lifetime", 0.18)

	# The enemy's swing gets the same animated slash the player's does, tinted red so
	# "incoming" never reads as "mine" in a crowded frame.
	anim(parent, pos + aim * reach * 0.4, "slash", reach * 1.8, Color("ff8a7a"), aim.angle())


static func heal(parent: Node, pos: Vector2) -> void:
	for i: int in range(5):
		var mote: Node2D = sprite(parent, pos + Vector2(randf_range(-9, 9), 0.0), TEX_MAGIC)
		if not mote:
			continue
		mote.set("color", Color("6ef2a0"))
		mote.set("start_size", 9.0)
		mote.set("end_size", 3.0)
		mote.set("lifetime", randf_range(0.45, 0.7))
		mote.set("velocity", Vector2(randf_range(-12, 12), randf_range(-58, -34)))
		mote.set("drag", 0.5)
