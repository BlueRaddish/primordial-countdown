# skill_data.gd
# Custom Resource for data-driven skill definitions.
# Unlock conditions are trait_name -> [min_stage, max_stage] ranges.
class_name SkillData
extends Resource

@export var skill_name: String = ""
@export var description: String = ""
@export var cooldown: float = 3.0
@export var damage: float = 40.0
@export var aoe_radius: float = 30.0
@export var aoe_color: Color = Color("4ecdc4")
@export var is_directional: bool = true # true = aimed at mouse, false = 360° around player

# Unlock conditions: Dictionary of trait_name -> Array[int] (size 2: [min_stage, max_stage]).
# All conditions must be met simultaneously for the skill to unlock.
# Example: {"arms": [5, 5], "legs": [0, 2]} means arms must be stage 5, legs between 0–2.
@export var unlock_conditions: Dictionary = {}


func is_unlocked(trait_states: Dictionary) -> bool:
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
