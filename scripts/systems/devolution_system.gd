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

# --- Devolution pacing ---
@export var years_per_devolution_base: float = 14.0
@export var years_per_devolution_growth: float = 2.0

# PLANNING1 milestone 3: the degradation order is fixed. The list is walked twice —
# once taking everything to partial, then again taking everything to fully lost —
# so the crippling losses (arms, legs) land late in the run.
@export var degradation_order: Array[String] = [
	"speech", "head", "eyes", "throat", "gut", "arms", "legs",
]

# --- State ---
var total_years: float = 0.0
var years_remaining: float = 0.0
var total_devolutions: int = 0
var attacks_made: int = 0
var years_spent_on_skills: float = 0.0

var _years_until_next: float = 14.0
var _awaiting_choice: bool = false
var _finished: bool = false


func _ready() -> void:
	add_to_group("devolution_system")
	total_years = compute_total_years()
	years_remaining = total_years
	_years_until_next = years_per_devolution_base

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


func compute_total_years() -> float:
	"""Years needed to walk every trait from intact to fully lost, at the
	widening cost-per-step. Spending exactly this much ends the run."""
	var steps: int = get_total_steps()
	var total: float = 0.0
	for i: int in range(steps):
		total += years_per_devolution_base + years_per_devolution_growth * float(i)
	return total


func get_total_steps() -> int:
	return degradation_order.size() * TraitManager.MAX_STAGE


# ---- The single entry point every driver routes through ----

func spend_years(amount: float) -> void:
	if not GameState.is_run_active or _finished or amount <= 0.0:
		return

	# Years are charged unconditionally, even while a devolution popup is pending.
	# Skipping the charge in that window would let anything fired during it happen
	# for free, and the run would end with devolutions still owed.
	years_remaining = maxf(years_remaining - amount, 0.0)
	_years_until_next -= amount
	EventBus.years_changed.emit(years_remaining, total_years)

	_try_trigger_devolution()


func _try_trigger_devolution() -> void:
	# One pending step at a time. Anything owed stays owed in _years_until_next
	# and fires as soon as the current step is resolved.
	if _awaiting_choice or _finished or _years_until_next > 0.0:
		return

	total_devolutions += 1
	# Accumulate rather than assign, so an overshoot carries into the next step
	# and the total cost of the run stays exactly compute_total_years().
	_years_until_next += (
		years_per_devolution_base + years_per_devolution_growth * float(total_devolutions)
	)
	_trigger_devolution()


func get_years_remaining() -> float:
	return years_remaining


func get_years_fraction() -> float:
	"""1.0 at the start of the run, 0.0 when fully devolved."""
	if total_years <= 0.0:
		return 0.0
	return clampf(years_remaining / total_years, 0.0, 1.0)


func get_progress() -> float:
	"""0.0 to 1.0 toward the next devolution step."""
	var step_cost: float = (
		years_per_devolution_base + years_per_devolution_growth * float(total_devolutions)
	)
	if step_cost <= 0.0:
		return 0.0
	return clampf(1.0 - (_years_until_next / step_cost), 0.0, 1.0)


# ---- Fixed degradation order ----

func get_next_trait(trait_mgr: TraitManager) -> String:
	"""Next trait in the fixed order that still has room to degrade, or "" if none."""
	if not trait_mgr:
		return ""
	# Pass 1: everything to partial. Pass 2: everything to fully lost.
	for target_stage: int in range(1, TraitManager.MAX_STAGE + 1):
		for trait_name: String in degradation_order:
			if trait_mgr.get_trait_stage(trait_name) < target_stage:
				return trait_name
	return ""


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
	total_years = compute_total_years()
	years_remaining = total_years
	_years_until_next = years_per_devolution_base
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
	var next_trait: String = get_next_trait(trait_mgr)
	if next_trait.is_empty():
		# Fully devolved. PLANNING1 section 4: the run ends here.
		_finished = true
		EventBus.player_died.emit()
		return
	_awaiting_choice = true
	EventBus.devolution_pending.emit(next_trait, total_devolutions)


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null
