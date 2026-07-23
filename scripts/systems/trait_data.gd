# trait_data.gd
# Custom Resource type for data-driven trait definitions.
# Save instances as .tres files in resources/traits/.
class_name TraitData
extends Resource

@export var trait_name: String
@export var max_stages: int = 3
@export var partial_stage_effects: Array[String]
@export var full_loss_effect: String
@export var full_loss_buff: String
