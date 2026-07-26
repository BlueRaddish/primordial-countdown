# era_door.gd
# Spawned by stage_manager.gd when a boss dies, this is the physical trigger for the
# next era's reskin. Unlike year_shrine.gd's F-press shrines, this fires on proximity
# alone — the player just has to walk into it, no interact key.
#
# One-shot: fires once, then queue_free()s. The arch it draws is procedural (same reason
# year_shrine.gd's own drawing is: a shape that always matches its own state beats a
# sprite that can go stale), tinted by which era it leads to.
class_name EraDoor
extends Area2D

const Vfx := preload("res://scripts/vfx/vfx.gd")

const INTERACT_RADIUS: float = 28.0

const ERA_TINTS: Dictionary = {
	StageManager.Era.INDUSTRIAL: Color("c9822e"), # amber — steam and brass
	StageManager.Era.CYBERPUNK: Color("2ecfe0"), # cyan — neon
}
const DEFAULT_TINT: Color = Color("9b59b6")

# The beat that marks an era change. Two lines, because the point is the turn between
# them: the world has moved forward and the body has not.
const COUPLET: String = "The doorway is newer than the ground.\nYou are older than you look."
const COUPLET_HEIGHT_FRACTION: float = 0.22 # Down from the top, clear of the HUD readouts.
const COUPLET_BOX_HEIGHT: float = 48.0
const COUPLET_FADE_IN: float = 0.6
const COUPLET_HOLD: float = 1.4
const COUPLET_FADE_OUT: float = 0.8

# Which era this door hands the player off to. Set by stage_manager.gd right after
# instantiation, before add_child().
var target_era: int = 0

var _pulse: float = 0.0
var _triggered: bool = false


func _ready() -> void:
	monitoring = true
	# Layer 0 / mask 1 ("player"), same as year_shrine.gd: detects the player and
	# nothing detects the door back, so it can never be hit or block movement.
	collision_layer = 0
	set_collision_mask_value(1, true)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _accent() -> Color:
	return ERA_TINTS.get(target_era, DEFAULT_TINT)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true

	var stage: Node = get_tree().get_first_node_in_group("stage_manager")
	if stage and stage.has_method("advance_to_era"):
		stage.call("advance_to_era", target_era)

	var accent: Color = _accent()
	_show_couplet(accent)
	var burst: Node2D = Vfx.sprite(get_parent(), global_position, Vfx.TEX_FLARE)
	if burst:
		burst.set("color", accent)
		burst.set("start_size", INTERACT_RADIUS * 0.7)
		burst.set("end_size", INTERACT_RADIUS * 3.5)
		burst.set("lifetime", 0.6)
	Vfx.buff(get_parent(), global_position + Vector2(0.0, -12.0), accent)

	queue_free()


func _show_couplet(accent: Color) -> void:
	"""Hold a two-line beat over the era change.

	Screen-space rather than a world Label at the archway: the player is walking through
	the door as this fires, so a world-anchored line would slide off with the camera and
	be sized by whatever zoom the arena happens to use.

	The whole thing is parented to the door's PARENT, not the door — _on_body_entered()
	queue_free()s the door on the same frame, and a child of a freed node never gets to
	run its tween. The tween is created on the layer itself for the same reason."""
	var host: Node = get_parent()
	if host == null:
		return

	var layer: CanvasLayer = CanvasLayer.new()
	# Above the arena, below the HUD's own layer so it can never cover the health bar.
	layer.layer = 1

	var label: Label = Label.new()
	# Deliberately not set: the font. project.godot already makes Kenney Pixel the
	# project-wide theme font, so overriding it here would only risk diverging from the
	# rest of the UI. Size is the one thing worth stating.
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", accent)
	# The couplet lands over whatever backdrop the next era brings, which is not a
	# surface anyone controls. An outline is what keeps it legible over all three.
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.text = COUPLET
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Anchored across the full width and placed by fraction of the real viewport, not by
	# Control.size — that is (0, 0) until after the first layout pass and has already
	# cost this project one invisible UI element.
	var view: Vector2 = get_viewport_rect().size
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = view.y * COUPLET_HEIGHT_FRACTION
	label.offset_bottom = label.offset_top + COUPLET_BOX_HEIGHT
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)

	layer.add_child(label)
	host.add_child(layer)

	# Fade in, hold, fade out — no game-time pause, the fight carries on underneath.
	var tween: Tween = layer.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, COUPLET_FADE_IN)
	tween.tween_interval(COUPLET_HOLD)
	tween.tween_property(label, "modulate:a", 0.0, COUPLET_FADE_OUT)
	tween.tween_callback(layer.queue_free)


# ---- Drawing ----
#
# An archway: two jambs and a lintel arc, the same doorway motif year_shrine.gd's
# PASSAGE kind draws, just larger and tinted per destination era instead of per shrine
# kind.

func _draw() -> void:
	var accent: Color = _accent()
	var breathe: float = 0.65 + 0.35 * sin(_pulse * 2.0)

	draw_circle(Vector2(0, -4), 26.0 * breathe, Color(accent, 0.14))

	draw_line(Vector2(-14, -6), Vector2(-14, -46), accent, 2.5)
	draw_line(Vector2(14, -6), Vector2(14, -46), accent, 2.5)
	draw_arc(Vector2(0, -46), 14.0, PI, TAU, 20, accent, 2.5)
	draw_rect(Rect2(-13, -46, 26, 40), Color(accent, 0.18 * breathe))

	draw_rect(Rect2(-18, -6, 36, 6), Color(accent, 0.5))
	draw_rect(Rect2(-18, -6, 36, 6), accent, false, 1.0)
