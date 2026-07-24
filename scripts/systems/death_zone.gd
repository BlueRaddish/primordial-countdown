# death_zone.gd
# Kills the player when they fall off the arena.
# Attach to an Area2D positioned below the visible arena.
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	# While testing with damage off, a bad jump should not end the run.
	if GameState.god_mode and body.has_method("respawn_at_start"):
		body.call("respawn_at_start")
		return

	EventBus.player_died.emit()
