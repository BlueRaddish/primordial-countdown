# year_shrine.gd
# A thing in the arena that sells you an advantage, priced in years off the
# countdown. ideate 2.1: "make the countdown a decision, not a meter."
#
# Until now the year counter was something that happened *to* the player — it drained
# as they swung and they watched it go. A shrine is the other half: a moment where
# spending the run's central currency is a live tactical choice with a number
# attached. The interesting question is never "do I want 45 health", it is "is 45
# health worth being one devolution closer to the end".
#
# Two kinds, both spawned between waves and gone when the next one starts:
#   REST     — heal, for a moderate price.
#   PASSAGE  — skip the next wave entirely, for a steep one.
#
# PASSAGE is deliberately the more interesting trade: skipping a wave saves you all
# the attacks that wave would have cost, so it can be *cheaper* than fighting it —
# but only if you would have spent more than its price clearing it. That is a real
# calculation rather than a straight tax.
class_name YearShrine
extends Area2D

enum Kind { REST, PASSAGE }

@export var kind: Kind = Kind.REST

const REST_COST: float = 40.0
const REST_HEAL: float = 45.0
const PASSAGE_COST: float = 60.0

const INTERACT_RADIUS: float = 30.0

var _player_inside: bool = false
var _used: bool = false
var _pulse: float = 0.0

var _prompt: Label


func _ready() -> void:
	add_to_group("year_shrine")
	monitoring = true
	# Layer 0 / mask 1 ("player"): the shrine detects the player and nothing detects
	# the shrine, so it can never be hit by an attack or block movement.
	collision_layer = 0
	set_collision_mask_value(1, true)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	add_child(shape)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.position = Vector2(-56.0, -54.0)
	_prompt.size = Vector2(112, 20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# A shrine now stands until it is used. It used to be cleared by the next wave
	# starting, which made it a between-waves decision — but the gap between waves is
	# only a few seconds, so in practice the offer vanished before it could be read,
	# let alone weighed. A standing shrine turns "spend years to heal" into a choice
	# you can walk away from and come back to mid-fight, which is the tactical decision
	# ideate 2.1 was after.


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()
	if _player_inside and not _used:
		_prompt.text = _prompt_text()
		_prompt.add_theme_color_override(
			"font_color", _accent() if _can_afford() else Color(0.6, 0.35, 0.35)
		)


func _unhandled_input(event: InputEvent) -> void:
	if _used or not _player_inside:
		return
	if not event.is_action_pressed("interact"):
		return
	_activate()


# ---- Pricing ----

func get_cost() -> float:
	return REST_COST if kind == Kind.REST else PASSAGE_COST


func _years_remaining() -> float:
	var devo: Node = get_tree().get_first_node_in_group("devolution_system")
	if devo and devo.has_method("get_years_remaining"):
		return devo.call("get_years_remaining")
	return 0.0


func _can_afford() -> bool:
	# Strictly greater, never equal: paying your last year would end the run on a
	# shrine, which is a miserable way to lose and not a trade anyone would take.
	return _years_remaining() > get_cost()


func _prompt_text() -> String:
	if not _can_afford():
		return "not enough years"
	if kind == Kind.REST:
		return "F — Rest   (%d yr)" % int(REST_COST)
	return "F — Force the passage   (%d yr)" % int(PASSAGE_COST)


func _accent() -> Color:
	return Color("2ecc71") if kind == Kind.REST else Color("9b59b6")


# ---- Use ----

func _activate() -> void:
	if not _can_afford():
		return
	_used = true
	_prompt.visible = false

	# Routed through the same signal skills use, so the countdown, the HUD and the
	# devolution thresholds all see it identically. A shrine is just an expensive
	# skill you walked to.
	EventBus.skill_cost_paid.emit(get_cost())

	match kind:
		Kind.REST:
			GameState.heal_player(REST_HEAL)
		Kind.PASSAGE:
			var spawner: Node = get_tree().get_first_node_in_group("wave_spawner")
			if spawner and spawner.has_method("skip_next_wave"):
				spawner.call("skip_next_wave")

	var flare: AoEIndicator = AoEIndicator.new()
	flare.aoe_center = global_position
	flare.aoe_radius = INTERACT_RADIUS * 1.6
	flare.aoe_color = _accent()
	flare.is_directional = false
	get_parent().add_child(flare)

	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	_prompt.visible = not _used


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_prompt.visible = false



# ---- Drawing ----
#
# Procedural for the same reason the body marks are: the shape has to follow the
# shrine's kind and affordability exactly, and a placeholder that is always correct
# beats a sprite that goes stale when the pricing is retuned.

func _draw() -> void:
	var accent: Color = _accent()
	var breathe: float = 0.65 + 0.35 * sin(_pulse * 2.0)
	var dim: bool = not _can_afford()
	if dim:
		accent = Color(0.45, 0.42, 0.45)

	# Glow pool on the ground.
	draw_circle(Vector2(0, -2), 22.0 * breathe, Color(accent, 0.14))

	# A low plinth.
	draw_rect(Rect2(-12, -8, 24, 8), Color(accent, 0.5))
	draw_rect(Rect2(-12, -8, 24, 8), accent, false, 1.0)

	if kind == Kind.REST:
		# A cupped basin: something to stop at.
		draw_arc(Vector2(0, -18), 9.0, PI, TAU, 16, accent, 2.0)
		draw_line(Vector2(-9, -18), Vector2(9, -18), Color(accent, breathe), 1.5)
	else:
		# A doorway: something to go through.
		draw_line(Vector2(-9, -8), Vector2(-9, -30), accent, 2.0)
		draw_line(Vector2(9, -8), Vector2(9, -30), accent, 2.0)
		draw_arc(Vector2(0, -30), 9.0, PI, TAU, 16, accent, 2.0)
		draw_rect(Rect2(-8, -30, 16, 22), Color(accent, 0.16 * breathe))
