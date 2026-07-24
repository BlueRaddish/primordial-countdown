# devolution_system.gd
# Player-driven devolution. Fed by combat performance through the devolution bar.
# IMPORTANT: Must never read evolution_system state. See PLANNING1 section 3.
#
# PLANNING1 section 5: keep one hidden devolution_points value and have every
# candidate driver call the same add_devolution_points(). Changing the driver means
# toggling which callers are active, not rewriting the system. The exported
# driver_* flags below are that toggle.
#
# Current driver: ATTACKS MADE. Every swing counts, landed or whiffed.
# Kills are deliberately off — PLANNING1 notes kill count per stage is close to
# fixed, which makes it a schedule with no skill expression.
extends Node

# --- Driver toggles. Exactly one is normally on. ---
@export var driver_attacks_made: bool = true
@export var driver_kills: bool = false
@export var driver_damage_dealt: bool = false
@export var driver_time_survived: bool = false
@export var driver_wave_clears: bool = false

# --- Points contributed per event, per driver ---
@export var points_per_attack: float = 1.0
@export var points_per_kill: float = 1.0
@export var points_per_damage: float = 0.02
@export var points_per_second: float = 0.5
@export var points_per_wave: float = 6.0

# --- Threshold ---
@export var base_threshold: float = 14.0
@export var threshold_growth: float = 2.0 # Added to the threshold after each step

# PLANNING1 milestone 3: the degradation order is fixed. The list is walked twice —
# once taking everything to partial, then again taking everything to fully lost —
# so the crippling losses (arms, legs) land late in the run.
@export var degradation_order: Array[String] = [
	"speech", "head", "eyes", "throat", "gut", "arms", "legs",
]

# --- Hidden state. The bar is what actually drives devolution. ---
var devolution_points: float = 0.0
var threshold: float = 14.0
var total_devolutions: int = 0
var attacks_made: int = 0

var _awaiting_choice: bool = false


func _ready() -> void:
	add_to_group("devolution_system")
	threshold = base_threshold

	if driver_attacks_made:
		EventBus.attack_made.connect(_on_attack_made)
	if driver_kills:
		EventBus.enemy_died.connect(_on_enemy_died)
	if driver_damage_dealt:
		EventBus.player_damage_dealt.connect(_on_damage_dealt)
	if driver_wave_clears:
		EventBus.wave_cleared.connect(_on_wave_cleared)


func _process(delta: float) -> void:
	if driver_time_survived and GameState.is_run_active:
		add_devolution_points(points_per_second * delta)


# ---- The single entry point every driver routes through ----

func add_devolution_points(amount: float) -> void:
	if not GameState.is_run_active or _awaiting_choice or amount <= 0.0:
		return

	devolution_points += amount
	EventBus.devolution_progress_changed.emit(get_progress())

	if devolution_points >= threshold:
		devolution_points -= threshold
		threshold += threshold_growth
		total_devolutions += 1
		_trigger_devolution()


func get_progress() -> float:
	"""Returns 0.0 to 1.0 progress toward the next devolution."""
	if threshold <= 0.0:
		return 0.0
	return clampf(devolution_points / threshold, 0.0, 1.0)


func get_total_steps() -> int:
	return degradation_order.size() * TraitManager.MAX_STAGE


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


func notify_choice_resolved() -> void:
	"""Called by the UI if it dismisses a devolution without applying it."""
	_awaiting_choice = false


func reset() -> void:
	devolution_points = 0.0
	threshold = base_threshold
	total_devolutions = 0
	attacks_made = 0
	_awaiting_choice = false


# ---- Driver callbacks. Each one is a candidate from PLANNING1's table. ----

func _on_attack_made() -> void:
	attacks_made += 1
	add_devolution_points(points_per_attack)


func _on_enemy_died(_enemy: Node) -> void:
	add_devolution_points(points_per_kill)


func _on_damage_dealt(amount: float) -> void:
	add_devolution_points(points_per_damage * amount)


func _on_wave_cleared(_wave_number: int) -> void:
	add_devolution_points(points_per_wave)


func _trigger_devolution() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	var next_trait: String = get_next_trait(trait_mgr)
	if next_trait.is_empty():
		# Fully devolved. PLANNING1 section 4: the run ends here.
		EventBus.player_died.emit()
		return
	_awaiting_choice = true
	EventBus.devolution_pending.emit(next_trait, total_devolutions)


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null
