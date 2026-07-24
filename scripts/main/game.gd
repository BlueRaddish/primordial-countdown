# game.gd
# Root of the playable scene.
#
# Normally GameState.start_new_run() sets the run up before this scene loads. If
# the scene is launched directly instead (F6 in the editor, or a headless run),
# start the run here so the arena is immediately testable without the menu.
extends Node2D


func _ready() -> void:
	if GameState.is_run_active:
		return

	GameState.player_health = GameState.player_max_health
	GameState.kill_count = 0
	GameState.current_wave = 0
	GameState.is_run_active = true
	EventBus.player_health_changed.emit(GameState.player_health, GameState.player_max_health)
