# death_screen.gd
# "You Died" overlay. Appears on player death, offers return to menu.
extends CanvasLayer

const PAUSE_ID: String = "death"

@onready var _panel: Control = $Control
@onready var _menu_btn: Button = $Control/VBoxContainer/MenuButton


func _ready() -> void:
	_panel.visible = false
	_menu_btn.pressed.connect(_on_menu_pressed)
	EventBus.player_died.connect(_on_player_died)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_player_died() -> void:
	if _panel.visible:
		return
	GameState.end_run()
	GameState.push_pause(PAUSE_ID)
	_panel.visible = true


func _on_menu_pressed() -> void:
	_panel.visible = false
	GameState.pop_pause(PAUSE_ID)
	GameState.return_to_menu()
