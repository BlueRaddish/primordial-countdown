# trait_manager.gd
# Holds the current stage of every trait. Single source of truth for player capability.
# Combat, movement, and UI all query this rather than tracking capability themselves.
# All stats are rebuilt from trait state on every change via recalculate_all().
#
# PLANNING1 section 6: each trait moves through intact -> partial -> fully_lost.
#   - Partial applies a scaling penalty with no reward.
#   - Full loss removes the trait's function entirely and grants one buff (a skill).
class_name TraitManager
extends Node

# --- Trait names ---
const TRAIT_ARMS: String = "arms"
const TRAIT_LEGS: String = "legs"
const TRAIT_GUT: String = "gut"
const TRAIT_THROAT: String = "throat"
const TRAIT_EYES: String = "eyes"
const TRAIT_HEAD: String = "head"
const TRAIT_SPEECH: String = "speech"

# --- Stages ---
const STAGE_INTACT: int = 0
const STAGE_PARTIAL: int = 1
const STAGE_LOST: int = 2
const MAX_STAGE: int = STAGE_LOST

const STAGE_NAMES: Array[String] = ["Intact", "Partial", "Lost"]

const ALL_TRAITS: Array[String] = ["arms", "legs", "gut", "throat", "eyes", "head", "speech"]

# --- Current trait stages: 0 = intact, 1 = partial, 2 = fully lost ---
var traits: Dictionary = {
	"arms": 0,
	"legs": 0,
	"gut": 0,
	"throat": 0,
	"eyes": 0,
	"head": 0,
	"speech": 0,
}

# --- Modifier lookup arrays (indexed by stage 0-2) ---
# Each returns a multiplier: 1.0 = full capability, 0.0 = none.
# Partial is a scaling penalty. Full loss zeroes the function out entirely.
var leg_speed_mods: Array[float] = [1.0, 0.6, 0.0]
var leg_jump_mods: Array[float] = [1.0, 0.75, 0.0]
var arm_range_mods: Array[float] = [1.0, 0.6, 0.0]
var arm_damage_mods: Array[float] = [1.0, 0.7, 0.0]
var gut_regen_mods: Array[float] = [1.0, 0.5, 0.0]
var throat_stamina_mods: Array[float] = [1.0, 0.5, 0.0]
var speech_cry_range_mods: Array[float] = [1.0, 0.5, 0.0]
var eyes_vision_mods: Array[float] = [1.0, 0.6, 0.0]
var head_info_mods: Array[float] = [1.0, 0.5, 0.0]

# --- Cached player reference ---
var _player: CharacterBody2D


func _ready() -> void:
	# Find player after the tree is fully set up.
	call_deferred("_find_player")


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as CharacterBody2D


# ---- Public API ----

func get_trait_stage(trait_name: String) -> int:
	if traits.has(trait_name):
		return traits[trait_name] as int
	return 0


func get_stage_name(trait_name: String) -> String:
	return STAGE_NAMES[get_trait_stage(trait_name)]


func is_intact(trait_name: String) -> bool:
	return get_trait_stage(trait_name) == STAGE_INTACT


func is_lost(trait_name: String) -> bool:
	return get_trait_stage(trait_name) >= STAGE_LOST


func get_modifier(trait_name: String) -> float:
	var stage: int = get_trait_stage(trait_name)
	match trait_name:
		"arms":
			return arm_range_mods[stage]
		"legs":
			return leg_speed_mods[stage]
		"gut":
			return gut_regen_mods[stage]
		"throat":
			return throat_stamina_mods[stage]
		"eyes":
			return eyes_vision_mods[stage]
		"head":
			return head_info_mods[stage]
		"speech":
			return speech_cry_range_mods[stage]
	return 1.0


func get_arm_damage_mod() -> float:
	return arm_damage_mods[get_trait_stage("arms")]


func get_leg_jump_mod() -> float:
	return leg_jump_mods[get_trait_stage("legs")]


func is_arms_blocked() -> bool:
	return get_trait_stage("arms") >= STAGE_LOST


func is_movement_blocked() -> bool:
	return get_trait_stage("legs") >= STAGE_LOST


func can_jump() -> bool:
	return get_trait_stage("legs") < STAGE_LOST


func count_lost_traits() -> int:
	var total: int = 0
	for trait_name: String in ALL_TRAITS:
		if is_lost(trait_name):
			total += 1
	return total


func devolve_trait(trait_name: String) -> void:
	if not traits.has(trait_name):
		return
	var current: int = traits[trait_name] as int
	if current >= MAX_STAGE:
		return

	traits[trait_name] = current + 1
	var new_stage: int = traits[trait_name] as int

	EventBus.trait_changed.emit(trait_name, new_stage)

	if new_stage >= MAX_STAGE:
		EventBus.trait_extinct.emit(trait_name)

	recalculate_all()


func set_trait_stage(trait_name: String, stage: int) -> void:
	"""Dev function: set a trait to a specific stage."""
	if not traits.has(trait_name):
		return
	traits[trait_name] = clampi(stage, 0, MAX_STAGE)
	EventBus.trait_changed.emit(trait_name, traits[trait_name] as int)
	if (traits[trait_name] as int) >= MAX_STAGE:
		EventBus.trait_extinct.emit(trait_name)
	recalculate_all()


func reset_all() -> void:
	for trait_name: String in ALL_TRAITS:
		traits[trait_name] = 0
	recalculate_all()


func recalculate_all() -> void:
	"""Rebuild every live stat on the player from current trait state."""
	if not _player:
		_find_player()
	if not _player:
		return
	if not _player.has_method("recalculate_from_traits"):
		return
	_player.recalculate_from_traits(self)
