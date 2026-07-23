# death_zone.gd
# Kills the player when they fall off the arena.
# Attach to an Area2D positioned below the visible arena.
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		EventBus.player_died.emit()
