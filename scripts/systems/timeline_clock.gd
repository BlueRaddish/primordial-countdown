# timeline_clock.gd
# Manages the run's progression timeline.
#
# PLANNING1 section 5: the hidden bar is what actually drives devolution; the
# readout is a display layer, it is logarithmic, and it visibly accelerates as the
# run progresses. This node owns that display layer and nothing else — it never
# feeds back into the devolution bar.
#
# Node is PAUSABLE, so elapsed run time stops whenever a screen pauses the game.
extends Node

const START_YEARS: float = 3.5e9 # Where the countdown reads at step 0
const END_YEARS: float = 1.0e3 # Where it reads once fully devolved

var elapsed: float = 0.0

var _devolution_system: Node


func _ready() -> void:
	add_to_group("timeline_clock")
	call_deferred("_find_devolution_system")


func _process(delta: float) -> void:
	if GameState.is_run_active:
		elapsed += delta


func get_elapsed_text() -> String:
	var total: int = int(elapsed)
	return "%d:%02d" % [total / 60, total % 60]


func get_run_fraction() -> float:
	"""0.0 at the start of the run, 1.0 once every trait is fully lost.

	Derived from actual trait state rather than from the devolution step counter,
	so the readout stays honest when traits are moved by anything other than the
	bar — the character screen's dev buttons, for instance."""
	var trait_mgr: TraitManager = _find_trait_manager()
	if not trait_mgr:
		return 0.0

	var max_total: int = TraitManager.ALL_TRAITS.size() * TraitManager.MAX_STAGE
	if max_total <= 0:
		return 0.0

	var stages: int = 0
	for trait_name: String in TraitManager.ALL_TRAITS:
		stages += trait_mgr.get_trait_stage(trait_name)

	var done: float = float(stages)

	# Blend in the partially filled bar, so the readout creeps between steps
	# instead of only moving when a devolution lands.
	if not _devolution_system:
		_find_devolution_system()
	if _devolution_system and stages < max_total:
		done += _devolution_system.call("get_progress")

	return clampf(done / float(max_total), 0.0, 1.0)


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null


func get_countdown_years() -> float:
	"""Logarithmic readout. Equal progress steps cut the remaining years by a
	constant factor, so the number falls slowly at first and then plummets."""
	var t: float = get_run_fraction()
	return START_YEARS * pow(END_YEARS / START_YEARS, t)


func get_countdown_text() -> String:
	var years: float = get_countdown_years()
	if years >= 1.0e9:
		return "%.2fB" % (years / 1.0e9)
	if years >= 1.0e6:
		return "%.1fM" % (years / 1.0e6)
	if years >= 1.0e3:
		return "%.0fK" % (years / 1.0e3)
	return "%.0f" % years


func reset() -> void:
	elapsed = 0.0


func _find_devolution_system() -> void:
	_devolution_system = get_tree().get_first_node_in_group("devolution_system")
