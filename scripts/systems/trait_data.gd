# trait_data.gd
# Custom Resource type for data-driven trait definitions.
# Used for display and configuration purposes.
# The actual stage/modifier logic lives in TraitManager.
class_name TraitData
extends Resource

@export var trait_name: String
@export var max_stages: int = 5
@export var stage_descriptions: Array[String] = []
@export var extinct_description: String = ""
@export var titan_buff_description: String = ""
