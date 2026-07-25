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

# The base trait whose slot this grows over. Also the exclusivity key: only one
# evolved trait may ever occupy a slot, so growing Wings closes off Claws (both
# grow from the arms) and Hide closes off Plates (both grow from the skin). The
# body is forced down one path, not all of them.
@export var replaces_trait: String = ""

# Combo of base-trait states that reveals this hidden option.
@export var unlock_conditions: Dictionary = {}

# --- Stat payloads, read by the systems that care ---
#
# Two conventions live here, and the difference matters:
#   * Neutral-valued fields (1.0 mult, 0.0 bonus) always apply — they are folded
#     into whatever the base traits produced.
#   * Override fields use 0.0 to mean "this trait says nothing about that stat",
#     because 0.0 is never a meaningful value for any of them.

# Passive damage-taken multiplier once grown; below 1.0 = tougher. (Hide, Plates)
@export var damage_taken_mult: float = 1.0

# Fraction of incoming knockback shrugged off, 0.0–1.0. (Plates)
@export var knockback_resist: float = 0.0

# Multiplier on mid-air steering authority. (Tail)
@export var air_control_mult: float = 1.0

# Extra seconds of coyote time — a tail is a balance organ. (Tail)
@export var coyote_bonus: float = 0.0

# Claws: a natural weapon, so the melee attack works again even with the arms
# gone. The two multipliers replace the (zeroed) arm ones rather than scaling them.
@export var restores_attack: bool = false
@export var attack_damage_mult: float = 0.0 # 0.0 = no override
@export var attack_range_mult: float = 0.0  # 0.0 = no override

# Gills: breathing moves off the ruined lungs, so swing recovery is paced by this
# instead of the lungs' penalty. (0.0 = no override)
@export var attack_cooldown_mult: float = 0.0


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
