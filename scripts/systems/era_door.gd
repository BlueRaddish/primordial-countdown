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
	var burst: Node2D = Vfx.sprite(get_parent(), global_position, Vfx.TEX_FLARE)
	if burst:
		burst.set("color", accent)
		burst.set("start_size", INTERACT_RADIUS * 0.7)
		burst.set("end_size", INTERACT_RADIUS * 3.5)
		burst.set("lifetime", 0.6)
	Vfx.buff(get_parent(), global_position + Vector2(0.0, -12.0), accent)

	queue_free()


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
