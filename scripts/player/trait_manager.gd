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

# --- Modifier lookup arrays (indexed by stage: 0 intact, 1 partial, 2 lost) ---
#
# Every trait carries a real, applied effect at BOTH partial and lost. Partial is a
# scaling penalty with no reward; lost removes the function outright and hands over
# a skill instead. Nothing here is decorative — if a number is in this file, some
# system reads it.

# Arms — PLANNING1: shorter reach at partial, no arm attacks at full loss.
var arm_damage_mods: Array[float] = [1.0, 0.7, 0.0]
var arm_range_mods: Array[float] = [1.0, 0.65, 0.0] # Scales melee hitbox length AND offset

# Legs — PLANNING1: slower and shorter dash at partial, no walking at full loss.
var leg_speed_mods: Array[float] = [1.0, 0.65, 0.0]
var leg_jump_mods: Array[float] = [1.0, 0.8, 0.0]

# Gut — PLANNING1: worse health regen at partial, none at full loss.
# Absolute health per second rather than a multiplier, so the value is readable.
var gut_regen_rates: Array[float] = [1.5, 0.5, 0.0]

# Throat — PLANNING1: slower stamina regen at partial, none at full loss.
# Expressed as how fast the player can swing again, rather than a separate bar.
var throat_cooldown_mults: Array[float] = [1.0, 1.5, 2.2]

# Eyes — PLANNING1: vision dims at partial, see only moving things at full loss.
# Drives world brightness. 1.0 = untouched.
var eyes_vision_mods: Array[float] = [1.0, 0.55, 0.22]

# Speech — PLANNING1: weaker battle cry at partial, none at full loss.
# A passive intimidation aura that slows nearby enemies.
var speech_intimidation_radius: Array[float] = [92.0, 46.0, 0.0]
var speech_intimidation_slow: Array[float] = [0.35, 0.18, 0.0]

# Head — PLANNING1: readouts get vaguer at partial, numbers hidden at full loss.
# The HUD reads the stage directly. Bars are never hidden, only the numbers:
# hiding the whole HUD would make the run unreadable rather than harder.
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
			return gut_regen_rates[stage]
		"throat":
			return throat_cooldown_mults[stage]
		"eyes":
			return eyes_vision_mods[stage]
		"head":
			return head_info_mods[stage]
		"speech":
			return speech_intimidation_slow[stage]
	return 1.0


func get_arm_damage_mod() -> float:
	return arm_damage_mods[get_trait_stage("arms")]


func get_arm_range_mod() -> float:
	return arm_range_mods[get_trait_stage("arms")]


func get_leg_jump_mod() -> float:
	return leg_jump_mods[get_trait_stage("legs")]


func get_gut_regen_rate() -> float:
	"""Health per second restored passively."""
	return gut_regen_rates[get_trait_stage("gut")]


func get_throat_cooldown_mult() -> float:
	"""Multiplier on attack cooldown. Above 1.0 means slower recovery between swings."""
	return throat_cooldown_mults[get_trait_stage("throat")]


func get_eyes_vision_mod() -> float:
	"""World brightness, 1.0 = untouched."""
	return eyes_vision_mods[get_trait_stage("eyes")]


func get_intimidation_radius() -> float:
	return speech_intimidation_radius[get_trait_stage("speech")]


func get_intimidation_slow() -> float:
	"""Fraction of chase speed removed from enemies inside the intimidation radius."""
	return speech_intimidation_slow[get_trait_stage("speech")]


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
