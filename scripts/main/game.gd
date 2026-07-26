# game.gd
# Root of the playable scene.
#
# Normally GameState.start_new_run() sets the run up before this scene loads. If
# the scene is launched directly instead (F6 in the editor, or a headless run),
# start the run here so the arena is immediately testable without the menu.
extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	# Esc opens settings, which freezes the run while it is up. The panel closes
	# itself on Esc, so this only ever has to handle opening it.
	if event.is_action_pressed("pause"):
		var panel: Node = get_tree().get_first_node_in_group("settings_panel")
		if panel and panel.has_method("toggle"):
			panel.call("toggle")
			get_viewport().set_input_as_handled()


func _ready() -> void:
	AudioManager.start_run_music()

	if GameState.is_run_active:
		return

	GameState.player_health = GameState.player_max_health
	GameState.kill_count = 0
	GameState.current_wave = 0
	GameState.is_run_active = true
	EventBus.player_health_changed.emit(GameState.player_health, GameState.player_max_health)
