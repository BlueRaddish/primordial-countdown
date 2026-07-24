# hud.gd
# In-game heads-up display. Health bar + devolution bar + wave counter + skill slots + settings.
extends CanvasLayer

@onready var _health_bar: ProgressBar = $Control/HealthBar
@onready var _settings_btn: Button = $Control/SettingsButton
@onready var _settings_panel: SettingsPanel = $Control/SettingsPanel

# Dynamically created UI elements.
var _devolution_bar: ProgressBar
var _devolution_label: Label
var _wave_label: Label
var _kill_label: Label
var _skill_slot_hud: Control


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	_settings_btn.pressed.connect(_on_settings_pressed)

	# Initialise health from current state.
	_health_bar.max_value = GameState.player_max_health
	_health_bar.value = GameState.player_health

	_build_devolution_bar()
	_build_wave_info()
	_build_skill_slots()


func _process(_delta: float) -> void:
	# Update devolution bar fill.
	if _devolution_bar:
		_devolution_bar.value = GameState.get_devolution_progress() * 100.0
	if _kill_label:
		_kill_label.text = "Kills: %d" % GameState.kill_count


func _build_devolution_bar() -> void:
	var control: Control = $Control

	# Devolution progress bar (below health bar).
	_devolution_bar = ProgressBar.new()
	_devolution_bar.position = Vector2(8, 24)
	_devolution_bar.size = Vector2(100, 8)
	_devolution_bar.max_value = 100.0
	_devolution_bar.value = 0.0
	_devolution_bar.show_percentage = false

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	bg_style.corner_radius_top_left = 1
	bg_style.corner_radius_top_right = 1
	bg_style.corner_radius_bottom_left = 1
	bg_style.corner_radius_bottom_right = 1
	_devolution_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color("e74c3c")
	fill_style.corner_radius_top_left = 1
	fill_style.corner_radius_top_right = 1
	fill_style.corner_radius_bottom_left = 1
	fill_style.corner_radius_bottom_right = 1
	_devolution_bar.add_theme_stylebox_override("fill", fill_style)

	control.add_child(_devolution_bar)

	# Label.
	_devolution_label = Label.new()
	_devolution_label.text = "DEVO"
	_devolution_label.position = Vector2(112, 22)
	_devolution_label.add_theme_font_size_override("font_size", 7)
	_devolution_label.add_theme_color_override("font_color", Color("e74c3c"))
	control.add_child(_devolution_label)


func _build_wave_info() -> void:
	var control: Control = $Control

	# Wave label.
	_wave_label = Label.new()
	_wave_label.text = "Wave: --"
	_wave_label.position = Vector2(8, 34)
	_wave_label.add_theme_font_size_override("font_size", 8)
	_wave_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	control.add_child(_wave_label)

	# Kill counter.
	_kill_label = Label.new()
	_kill_label.text = "Kills: 0"
	_kill_label.position = Vector2(80, 34)
	_kill_label.add_theme_font_size_override("font_size", 8)
	_kill_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	control.add_child(_kill_label)


func _build_skill_slots() -> void:
	var control: Control = $Control

	# Skill slot HUD at bottom-left.
	var slot_hud_script: GDScript = load("res://scripts/ui/skill_slot_hud.gd") as GDScript
	_skill_slot_hud = Control.new()
	_skill_slot_hud.set_script(slot_hud_script)
	_skill_slot_hud.position = Vector2(8, 326) # Near bottom of 360px viewport
	control.add_child(_skill_slot_hud)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_wave_started(wave_number: int, _enemy_count: int) -> void:
	if _wave_label:
		_wave_label.text = "Wave: %d" % wave_number


func _on_wave_cleared(wave_number: int) -> void:
	if _wave_label:
		_wave_label.text = "Wave: %d ✓" % wave_number


func _on_settings_pressed() -> void:
	_settings_panel.open()
