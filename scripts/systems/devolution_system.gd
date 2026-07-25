# devolution_system.gd
# Player-driven devolution. Fed by combat performance.
# IMPORTANT: Must never read evolution_system state. See PLANNING1 section 3.
#
# The run is a countdown of YEARS. There is no separate hidden bar — the year
# counter IS the devolution counter, and it is the thing shown on the HUD.
#
#   normal attack  -> 1 year
#   skill          -> the skill's own year_cost (some are free, see below)
#
# Devolution fires every time enough years have been burned, and the gap widens
# each step. Starting years are computed so that spending the last year lands
# exactly on the last devolution: reaching 0 means fully devolved, which is
# PLANNING1 section 4's end condition.
#
# PLANNING1 section 5 asked for the driver to stay swappable: everything routes
# through spend_years(), and the driver_* exports decide who calls it.
extends Node

# --- Driver toggles. Attacks + skill costs are the shipped driver. ---
@export var driver_attacks_made: bool = true
@export var driver_skill_costs: bool = true
@export var driver_kills: bool = false
@export var driver_damage_dealt: bool = false
@export var driver_time_survived: bool = false
@export var driver_wave_clears: bool = false

# --- Years charged per event, per driver ---
@export var years_per_attack: float = 1.0
@export var years_per_kill: float = 1.0
@export var years_per_damage: float = 0.02
@export var years_per_second: float = 0.5
@export var years_per_wave: float = 6.0

# --- Run length ---
# The single knob for how long a run is. Every devolution step is derived from it,
# so raising this lengthens the run without desynchronising anything.
@export var starting_years: float = 2000.0

# Shape of the devolution schedule. 0.0 spaces every step evenly; 2.0 makes the
# last step cost 3x the first, so devolution starts slow and accelerates.
@export var devolution_curve_growth: float = 2.0

# Each devolution offers a randomized choice of this many traits to degrade; the
# player picks one. (PLANNING1 section 6's "player chosen degradation" — promoted
# from a dev toggle to the standard flow, so runs are shaped by choice, not a fixed
# script, and evolved-trait combos can be steered toward on purpose.)
@export var devolution_choice_count: int = 3

# Retained only to size the countdown schedule: total_steps = size * MAX_STAGE = 14
# degradations, whatever order they are chosen in. The order of the entries no
# longer drives anything — every trait is a candidate every step.
@export var degradation_order: Array[String] = [
	"skin", "head", "eyes", "lungs", "gut", "arms", "legs",
]

# --- State ---
var total_years: float = 0.0
var years_remaining: float = 0.0
var total_devolutions: int = 0
var attacks_made: int = 0
var years_spent_on_skills: float = 0.0

# Cost in years of each devolution step, index 0 = first step.
var _step_costs: Array[float] = []
# Cumulative years-spent value at which each step fires. Tracking absolute
# thresholds rather than a decrementing counter keeps the schedule free of
# floating point drift, so the final step always lands exactly at zero years.
var _thresholds: Array[float] = []
var _awaiting_choice: bool = false
var _finished: bool = false


func _ready() -> void:
	add_to_group("devolution_system")
	_build_step_costs()
	total_years = starting_years
	years_remaining = total_years

	if driver_attacks_made:
		EventBus.attack_made.connect(_on_attack_made)
	if driver_skill_costs:
		EventBus.skill_cost_paid.connect(_on_skill_cost_paid)
	if driver_kills:
		EventBus.enemy_died.connect(_on_enemy_died)
	if driver_damage_dealt:
		EventBus.player_damage_dealt.connect(_on_damage_dealt)
	if driver_wave_clears:
		EventBus.wave_cleared.connect(_on_wave_cleared)

	call_deferred("_announce")


func _announce() -> void:
	EventBus.years_changed.emit(years_remaining, total_years)


func _process(delta: float) -> void:
	if driver_time_survived and GameState.is_run_active:
		spend_years(years_per_second * delta)


func _build_step_costs() -> void:
	"""Spread starting_years across the devolution steps along the growth curve.

	The costs are normalised to sum to exactly starting_years, so spending the
	last year lands on the last devolution: reaching 0 means fully devolved."""
	_step_costs.clear()
	var steps: int = get_total_steps()
	if steps <= 0:
		return

	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for i: int in range(steps):
		var t: float = 0.0 if steps <= 1 else float(i) / float(steps - 1)
		var w: float = 1.0 + devolution_curve_growth * t
		weights.append(w)
		weight_sum += w

	var assigned: float = 0.0
	for i: int in range(steps):
		var cost: float = starting_years * weights[i] / weight_sum
		_step_costs.append(cost)
		assigned += cost

	# Absorb any floating point remainder into the final step so the totals match.
	_step_costs[steps - 1] += starting_years - assigned

	_thresholds.clear()
	var running: float = 0.0
	for cost: float in _step_costs:
		running += cost
		_thresholds.append(running)
	# Pin the last threshold exactly, so spending the final year always fires the
	# final devolution rather than missing it by an epsilon.
	_thresholds[steps - 1] = starting_years


func get_step_costs() -> Array[float]:
	return _step_costs


func get_total_steps() -> int:
	return degradation_order.size() * TraitManager.MAX_STAGE


# ---- The single entry point every driver routes through ----

func spend_years(amount: float) -> void:
	if not GameState.is_run_active or _finished or amount <= 0.0:
		return

	# Testing mode: hold the countdown still so a skill can be exercised for as
	# long as it takes without burning the run down.
	if GameState.freeze_years:
		return

	# Years are charged unconditionally, even while a devolution popup is pending.
	# Skipping the charge in that window would let anything fired during it happen
	# for free, and the run would end with devolutions still owed.
	years_remaining = maxf(years_remaining - amount, 0.0)
	EventBus.years_changed.emit(years_remaining, total_years)

	_try_trigger_devolution()


func _try_trigger_devolution() -> void:
	# One pending step at a time. Anything owed while a popup is open stays owed
	# and fires as soon as the current step is resolved.
	if _awaiting_choice or _finished:
		return
	if total_devolutions >= _thresholds.size():
		return
	if get_years_spent() + 0.0001 < _thresholds[total_devolutions]:
		return

	total_devolutions += 1
	_trigger_devolution()


func get_years_remaining() -> float:
	return years_remaining


func get_years_spent() -> float:
	return total_years - years_remaining


func get_years_fraction() -> float:
	"""1.0 at the start of the run, 0.0 when fully devolved."""
	if total_years <= 0.0:
		return 0.0
	return clampf(years_remaining / total_years, 0.0, 1.0)


func get_progress() -> float:
	"""0.0 to 1.0 toward the next devolution step."""
	if total_devolutions >= _thresholds.size():
		return 0.0
	var prev: float = 0.0 if total_devolutions == 0 else _thresholds[total_devolutions - 1]
	var span: float = _thresholds[total_devolutions] - prev
	if span <= 0.0:
		return 0.0
	return clampf((get_years_spent() - prev) / span, 0.0, 1.0)


# ---- Fixed degradation order ----

func get_next_trait(trait_mgr: TraitManager) -> String:
	"""First trait (in list order) that still has room to degrade, or "" if none.
	Kept as a fallback; the main flow offers a choice via get_devolution_options()."""
	if not trait_mgr:
		return ""
	for target_stage: int in range(1, TraitManager.MAX_STAGE + 1):
		for trait_name: String in degradation_order:
			if trait_mgr.get_trait_stage(trait_name) < target_stage:
				return trait_name
	return ""


func get_devolution_options(trait_mgr: TraitManager, count: int) -> Array[String]:
	"""A randomized set of traits the player may choose to degrade this step.

	Every trait that still has room (stage < lost) is a candidate. Normally a
	shuffled subset of `count`; the dev "reveal all" toggle returns every candidate
	so a tester can steer straight to any trait or evolved-trait combo."""
	var candidates: Array[String] = []
	if not trait_mgr:
		return candidates
	for trait_name: String in TraitManager.ALL_TRAITS:
		if trait_mgr.get_trait_stage(trait_name) < TraitManager.MAX_STAGE:
			candidates.append(trait_name)

	if GameState.devolution_player_choice:
		return candidates

	candidates.shuffle()
	if candidates.size() > count:
		candidates = candidates.slice(0, count)
	return candidates


func apply_devolution(trait_name: String, trait_mgr: TraitManager) -> void:
	if not trait_mgr or trait_name.is_empty():
		_awaiting_choice = false
		return
	trait_mgr.devolve_trait(trait_name)
	EventBus.devolution_applied.emit(trait_name, trait_mgr.get_trait_stage(trait_name))
	_awaiting_choice = false
	# Years burned while the popup was open may already owe another step.
	_try_trigger_devolution()


func notify_choice_resolved() -> void:
	"""Called by the UI if it dismisses a devolution without applying it."""
	_awaiting_choice = false
	_try_trigger_devolution()


func reset() -> void:
	_build_step_costs()
	total_years = starting_years
	years_remaining = total_years
	total_devolutions = 0
	attacks_made = 0
	years_spent_on_skills = 0.0
	_awaiting_choice = false
	_finished = false
	EventBus.years_changed.emit(years_remaining, total_years)


# ---- Driver callbacks. Each one is a candidate from PLANNING1's table. ----

func _on_attack_made() -> void:
	attacks_made += 1
	spend_years(years_per_attack)


func _on_skill_cost_paid(years: float) -> void:
	years_spent_on_skills += years
	spend_years(years)


func _on_enemy_died(_enemy: Node) -> void:
	spend_years(years_per_kill)


func _on_damage_dealt(amount: float) -> void:
	spend_years(years_per_damage * amount)


func _on_wave_cleared(_wave_number: int) -> void:
	spend_years(years_per_wave)


func _trigger_devolution() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	var options: Array[String] = get_devolution_options(trait_mgr, devolution_choice_count)
	if options.is_empty():
		# Nothing left to lose — fully devolved. PLANNING1 section 4: the run ends.
		_finished = true
		EventBus.player_died.emit()
		return
	_awaiting_choice = true
	EventBus.devolution_pending.emit(options, total_devolutions)


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null
