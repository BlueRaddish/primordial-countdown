# evolved_trait_data.gd
# Data-driven definition of an *evolved* trait — an older feature the lineage once
# had and can grow back in over a trait it has lost.
#
# PLANNING1 section 6 "Traits regained": some devolutions grant rather than remove.
# An evolved trait is exactly that, but hidden: it only surfaces once a specific
# combination of losses is reached, and then only as an offer. Accepting it grows
# the feature and permanently takes over the role of the trait it replaces;
# declining leaves the normal degradation untouched.
#
# Unlock conditions read the *base* trait states, trait_name -> [min_stage,
# max_stage], same encoding as SkillData. Skills that the evolved trait grants
# key off the evolved id as a pseudo-trait (stage 0 dormant, 1 grown), which
# AbilityManager merges into the state dictionary it checks skills against.
class_name EvolvedTraitData
extends Resource

@export var id: String = ""              # "wings", "hide" — the pseudo-trait key
@export var display_name: String = ""    # "Wings"
@export var description: String = ""     # what it does, one line
@export var flavor: String = ""          # mood line
@export var color: Color = Color("cddc39")

# The base trait whose slot this grows over. Purely for presentation — the base
# trait is already lost by the time the combo is reached.
@export var replaces_trait: String = ""

# Combo of base-trait states that reveals this hidden option.
@export var unlock_conditions: Dictionary = {}

# --- Stat payloads, read by the systems that care ---
# Hide: passive damage-taken multiplier once grown (below 1.0 = tougher).
@export var hide_damage_mult: float = 1.0


func is_eligible(trait_states: Dictionary) -> bool:
	"""True when the base-trait combo that reveals this option is currently met."""
	if unlock_conditions.is_empty():
		return false
	for trait_name: String in unlock_conditions:
		if not trait_states.has(trait_name):
			return false
		var stage: int = trait_states[trait_name] as int
		var bounds: Array = unlock_conditions[trait_name] as Array
		if bounds.size() < 2:
			return false
		if stage < (bounds[0] as int) or stage > (bounds[1] as int):
			return false
	return true


func get_requirement_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for trait_name: String in unlock_conditions:
		var bounds: Array = unlock_conditions[trait_name] as Array
		if bounds.size() < 2:
			continue
		var lo: int = bounds[0] as int
		var hi: int = bounds[1] as int
		var stage_text: String = TraitManager.STAGE_NAMES[lo].to_lower()
		if lo != hi:
			stage_text = "%s-%s" % [
				TraitManager.STAGE_NAMES[lo].to_lower(),
				TraitManager.STAGE_NAMES[hi].to_lower(),
			]
		parts.append("%s %s" % [trait_name.capitalize(), stage_text])
	return ", ".join(parts)
