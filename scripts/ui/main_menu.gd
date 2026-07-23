# main_menu.gd
# Main menu with pixel art title and menu buttons.
extends Control

@onready var _settings_panel: SettingsPanel = $SettingsPanel
@onready var _new_game_btn: Button = $VBoxContainer/NewGameButton
@onready var _load_game_btn: Button = $VBoxContainer/LoadGameButton
@onready var _settings_btn: Button = $VBoxContainer/SettingsButton
@onready var _quit_btn: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	_new_game_btn.pressed.connect(_on_new_game)
	_load_game_btn.pressed.connect(_on_load_game)
	_settings_btn.pressed.connect(_on_settings)
	_quit_btn.pressed.connect(_on_quit)
	# Load game not implemented yet.
	_load_game_btn.disabled = true


func _on_new_game() -> void:
	GameState.start_new_run()


func _on_load_game() -> void:
	pass # Not implemented yet.


func _on_settings() -> void:
	_settings_panel.open()


func _on_quit() -> void:
	get_tree().quit()
