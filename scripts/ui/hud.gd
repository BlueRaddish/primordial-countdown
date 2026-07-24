# hud.gd
# In-game heads-up display.
# Health, devolution bar + countdown readout, wave/kill info, boss bar,
# active buffs, skill slots, and the god-mode testing flag.
extends CanvasLayer

@onready var _health_bar: ProgressBar = $Control/HealthBar
@onready var _settings_btn: Button = $Control/SettingsButton
@onready var _settings_panel: SettingsPanel = $Control/SettingsPanel

# Dynamically created UI elements.
var _devolution_bar: ProgressBar
var _devolution_label: Label
var _countdown_label: Label
var _wave_label: Label
var _kill_label: Label
var _time_label: Label
var _god_label: Label
var _buff_label: Label
var _skill_slot_hud: Control

# Boss bar.
var _boss_bar: ProgressBar
var _boss_label: Label

var _devolution_system: Node
var _timeline_clock: Node
var _status_effects: StatusEffects


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.god_mode_changed.connect(_on_god_mode_changed)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_settings_btn.pressed.connect(_on_settings_pressed)

	# Initialise health from current state.
	_health_bar.max_value = GameState.player_max_health
	_health_bar.value = GameState.player_health

	_build_devolution_bar()
	_build_run_info()
	_build_boss_bar()
	_build_skill_slots()

	call_deferred("_find_systems")


func _find_systems() -> void:
	_devolution_system = get_tree().get_first_node_in_group("devolution_system")
	_timeline_clock = get_tree().get_first_node_in_group("timeline_clock")
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("StatusEffects"):
		_status_effects = players[0].get_node("StatusEffects") as StatusEffects


func _process(_delta: float) -> void:
	if _devolution_bar and _devolution_system:
		_devolution_bar.value = _devolution_system.call("get_progress") * 100.0

	if _countdown_label and _timeline_clock:
		_countdown_label.text = "%s yr" % _timeline_clock.call("get_countdown_text")

	if _time_label and _timeline_clock:
		_time_label.text = _timeline_clock.call("get_elapsed_text")

	if _kill_label and _devolution_system:
		_kill_label.text = "Kills: %d   Atk: %d" % [
			GameState.kill_count,
			_devolution_system.get("attacks_made"),
		]

	_update_buff_label()


# ---- Builders ----

func _build_devolution_bar() -> void:
	var control: Control = $Control

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

	_devolution_label = Label.new()
	_devolution_label.text = "DEVO"
	_devolution_label.position = Vector2(112, 22)
	_devolution_label.add_theme_font_size_override("font_size", 7)
	_devolution_label.add_theme_color_override("font_color", Color("e74c3c"))
	control.add_child(_devolution_label)

	# PLANNING1 section 5: the bar drives devolution, the readout is a display
	# layer, and the readout is logarithmic.
	_countdown_label = Label.new()
	_countdown_label.text = "--"
	_countdown_label.position = Vector2(142, 22)
	_countdown_label.add_theme_font_size_override("font_size", 7)
	_countdown_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	control.add_child(_countdown_label)


func _build_run_info() -> void:
	var control: Control = $Control

	_wave_label = Label.new()
	_wave_label.text = "Wave: --"
	_wave_label.position = Vector2(8, 34)
	_wave_label.add_theme_font_size_override("font_size", 8)
	_wave_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	control.add_child(_wave_label)

	_kill_label = Label.new()
	_kill_label.text = "Kills: 0   Atk: 0"
	_kill_label.position = Vector2(60, 34)
	_kill_label.add_theme_font_size_override("font_size", 8)
	_kill_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	control.add_child(_kill_label)

	_time_label = Label.new()
	_time_label.text = "0:00"
	_time_label.position = Vector2(8, 44)
	_time_label.add_theme_font_size_override("font_size", 8)
	_time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	control.add_child(_time_label)

	_buff_label = Label.new()
	_buff_label.text = ""
	_buff_label.position = Vector2(8, 54)
	_buff_label.add_theme_font_size_override("font_size", 8)
	_buff_label.add_theme_color_override("font_color", Color("f1c40f"))
	control.add_child(_buff_label)

	# Testing flag — deliberately loud so nobody reads a god-mode run as a real one.
	_god_label = Label.new()
	_god_label.text = "GOD MODE — no damage taken"
	_god_label.position = Vector2(8, 66)
	_god_label.add_theme_font_size_override("font_size", 8)
	_god_label.add_theme_color_override("font_color", Color("2ecc71"))
	_god_label.visible = GameState.god_mode
	control.add_child(_god_label)

	var hint: Label = Label.new()
	hint.text = "[C] Character  [Q/E/R] Skills"
	hint.position = Vector2(8, 340)
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	control.add_child(hint)


func _build_boss_bar() -> void:
	var control: Control = $Control

	_boss_label = Label.new()
	_boss_label.text = "STAGE BOSS"
	_boss_label.position = Vector2(248, 8)
	_boss_label.add_theme_font_size_override("font_size", 8)
	_boss_label.add_theme_color_override("font_color", Color("c0392b"))
	_boss_label.visible = false
	control.add_child(_boss_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.position = Vector2(200, 20)
	_boss_bar.size = Vector2(240, 8)
	_boss_bar.max_value = 100.0
	_boss_bar.value = 100.0
	_boss_bar.show_percentage = false
	_boss_bar.visible = false

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.08, 0.08, 0.85)
	_boss_bar.add_theme_stylebox_override("background", bg)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("c0392b")
	_boss_bar.add_theme_stylebox_override("fill", fill)

	control.add_child(_boss_bar)


func _build_skill_slots() -> void:
	var control: Control = $Control

	var slot_hud_script: GDScript = load("res://scripts/ui/skill_slot_hud.gd") as GDScript
	_skill_slot_hud = Control.new()
	_skill_slot_hud.set_script(slot_hud_script)
	_skill_slot_hud.position = Vector2(8, 300)
	control.add_child(_skill_slot_hud)


# ---- Updates ----

func _update_buff_label() -> void:
	if not _buff_label:
		return
	if not _status_effects:
		_buff_label.text = ""
		return

	var parts: PackedStringArray = PackedStringArray()
	for buff: StatusEffects.ActiveBuff in _status_effects.get_active_buffs():
		parts.append("%s %.1fs" % [buff.id, buff.time_left])
	_buff_label.text = "  ".join(parts)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_wave_started(wave_number: int, _enemy_count: int) -> void:
	if _wave_label:
		_wave_label.text = "Wave: %d" % wave_number


func _on_wave_cleared(wave_number: int) -> void:
	if _wave_label:
		_wave_label.text = "Wave: %d ok" % wave_number


func _on_god_mode_changed(enabled: bool) -> void:
	if _god_label:
		_god_label.visible = enabled


func _on_boss_spawned(_boss: Node, maximum: float) -> void:
	if not _boss_bar:
		return
	_boss_bar.max_value = maximum
	_boss_bar.value = maximum
	_boss_bar.visible = true
	_boss_label.visible = true


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if not _boss_bar:
		return
	_boss_bar.max_value = maximum
	_boss_bar.value = current


func _on_boss_defeated() -> void:
	if _boss_bar:
		_boss_bar.visible = false
	if _boss_label:
		_boss_label.visible = false


func _on_settings_pressed() -> void:
	_settings_panel.open()
