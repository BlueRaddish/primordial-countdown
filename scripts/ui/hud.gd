# hud.gd
# In-game heads-up display. Health bar + settings button.
extends CanvasLayer

@onready var _health_bar: ProgressBar = $Control/HealthBar
@onready var _settings_btn: Button = $Control/SettingsButton
@onready var _settings_panel: SettingsPanel = $Control/SettingsPanel


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	# Initialise from current state.
	_health_bar.max_value = GameState.player_max_health
	_health_bar.value = GameState.player_health


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_settings_pressed() -> void:
	_settings_panel.open()
