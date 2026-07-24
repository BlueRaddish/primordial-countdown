# skill_data.gd
# Custom Resource for data-driven skill definitions.
#
# A skill is the buff PLANNING1 section 6 grants when a trait is fully lost. It is
# unlocked by trait state, never bought, and it always costs a cooldown.
#
# Unlock conditions are trait_name -> [min_stage, max_stage] with stages
# 0 = intact, 1 = partial, 2 = fully lost. A skill naming more than one trait is a
# multi-trait skill: it reads a *combination* of capability, not a single loss.
#
# Every skill can carry up to three components and applies whichever are non-zero:
#   1. Offensive  — instant AoE damage       (aoe_damage > 0)
#   2. Buff       — timed self modifiers     (buff_duration > 0)
#   3. Impulse    — alternative movement     (impulse_speed > 0)
class_name SkillData
extends Resource

enum Kind { OFFENSIVE, BUFF, MOVEMENT }

@export var skill_name: String = ""
@export var description: String = ""
@export var flavor: String = ""
@export var kind: Kind = Kind.OFFENSIVE
@export var cooldown: float = 3.0

# --- Offensive component ---
@export var aoe_damage: float = 0.0
@export var aoe_radius: float = 30.0
@export var aoe_color: Color = Color("4ecdc4")
@export var is_directional: bool = true # true = aimed at mouse, false = 360 around player

# --- Buff component ---
@export var buff_duration: float = 0.0
@export var buff_damage_mult: float = 1.0
@export var buff_damage_taken_mult: float = 1.0
@export var buff_omnivamp: float = 0.0 # Fraction of damage dealt returned as health
@export var buff_contact_retaliation: float = 0.0 # Damage to enemies touching the player
@export var buff_attack_cooldown_mult: float = 1.0
@export var buff_pulse_damage: float = 0.0
@export var buff_pulse_radius: float = 0.0
@export var buff_pulse_interval: float = 0.0

# --- Impulse component ---
@export var impulse_speed: float = 0.0
@export var impulse_upward_bias: float = 0.0 # Extra upward velocity added to the impulse

# Unlock conditions: trait_name -> Array[int] of size 2: [min_stage, max_stage].
# All conditions must be met simultaneously.
@export var unlock_conditions: Dictionary = {}


func is_unlocked(trait_states: Dictionary) -> bool:
	if unlock_conditions.is_empty():
		return false
	for trait_name: String in unlock_conditions:
		if not trait_states.has(trait_name):
			return false
		var stage: int = trait_states[trait_name] as int
		var bounds: Array = unlock_conditions[trait_name] as Array
		if bounds.size() < 2:
			return false
		var min_stage: int = bounds[0] as int
		var max_stage: int = bounds[1] as int
		if stage < min_stage or stage > max_stage:
			return false
	return true


func is_multi_trait() -> bool:
	return unlock_conditions.size() > 1


func get_trait_tags() -> Array[String]:
	var tags: Array[String] = []
	for trait_name: String in unlock_conditions:
		tags.append(trait_name)
	return tags


func get_kind_label() -> String:
	match kind:
		Kind.BUFF:
			return "BUFF"
		Kind.MOVEMENT:
			return "MOVE"
		_:
			return "ATTACK"


func get_requirement_text() -> String:
	"""Human readable unlock requirement, e.g. 'Arms lost, Legs intact-partial'."""
	var parts: PackedStringArray = PackedStringArray()
	for trait_name: String in unlock_conditions:
		var bounds: Array = unlock_conditions[trait_name] as Array
		if bounds.size() < 2:
			continue
		var lo: int = bounds[0] as int
		var hi: int = bounds[1] as int
		var stage_text: String = ""
		if lo == hi:
			stage_text = TraitManager.STAGE_NAMES[lo].to_lower()
		else:
			stage_text = "%s-%s" % [
				TraitManager.STAGE_NAMES[lo].to_lower(),
				TraitManager.STAGE_NAMES[hi].to_lower(),
			]
		parts.append("%s %s" % [trait_name.capitalize(), stage_text])
	return ", ".join(parts)
