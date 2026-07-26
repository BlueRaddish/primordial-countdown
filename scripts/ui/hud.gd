# hud.gd
# In-game heads-up display.
# Health, devolution bar + countdown readout, wave/kill info, boss bar,
# active buffs, skill slots, and the god-mode testing flag.
extends CanvasLayer

# The countdown is the one number on screen that changes constantly, so it gets a
# monospaced face while the rest of the UI uses the project's default pixel font.
# In a proportional font the digits are different widths, and 2000 -> 0 makes the
# whole readout twitch sideways as it ticks. Monospace holds it still, and keeps
# the Head trait's degraded readouts ("~25", "??") the same width as the real one.
const COUNTER_FONT: FontFile = preload("res://assets/fonts/Kenney Mini Square Mono.ttf")

@onready var _health_bar: ProgressBar = $Control/HealthBar
@onready var _settings_btn: Button = $Control/SettingsButton
@onready var _settings_panel: SettingsPanel = $Control/SettingsPanel

# Dynamically created UI elements.
var _year_label: Label
var _year_tag_label: Label
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

# Head trait stage. Drives how precise the readouts are:
#   0 intact  — exact numbers
#   1 partial — numbers rounded and prefixed with ~
#   2 lost    — numbers replaced with ???
# The bars themselves are never hidden. Hiding the whole HUD would make the run
# unreadable rather than harder.
var _head_stage: int = TraitManager.STAGE_INTACT


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.trait_changed.connect(_on_trait_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.test_modes_changed.connect(_refresh_test_banner)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_settings_btn.pressed.connect(_on_settings_pressed)

	# Initialise health from current state.
	_health_bar.max_value = GameState.player_max_health
	_health_bar.value = GameState.player_health

	_build_year_counter()
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
	if _year_label and _devolution_system:
		var years: float = _devolution_system.call("get_years_remaining")
		if _head_stage >= TraitManager.STAGE_LOST:
			_year_label.text = "???"
		elif _head_stage == TraitManager.STAGE_PARTIAL:
			_year_label.text = "~%d" % (int(round(years / 5.0)) * 5)
		else:
			_year_label.text = "%d" % int(ceil(years))
		# Redden as the countdown runs out.
		var t: float = 1.0 - (_devolution_system.call("get_years_fraction") as float)
		_year_label.add_theme_color_override(
			"font_color", Color("e8b0b0").lerp(Color("ff2d2d"), t)
		)

	if _countdown_label and _timeline_clock:
		if _head_stage >= TraitManager.STAGE_LOST:
			_countdown_label.text = "??? yr"
		elif _head_stage == TraitManager.STAGE_PARTIAL:
			_countdown_label.text = "~%s yr" % _timeline_clock.call("get_countdown_text")
		else:
			_countdown_label.text = "%s yr" % _timeline_clock.call("get_countdown_text")

	if _time_label and _timeline_clock:
		_time_label.text = _timeline_clock.call("get_elapsed_text")

	if _kill_label and _devolution_system:
		var kills: int = GameState.kill_count
		var attacks: int = _devolution_system.get("attacks_made") as int
		_kill_label.text = "Kills: %s   Atk: %s" % [_vague(kills, 5), _vague(attacks, 10)]

	_update_buff_label()


func _vague(value: int, bucket: int) -> String:
	"""Render a number at the precision the head trait still allows."""
	match _head_stage:
		TraitManager.STAGE_LOST:
			return "??"
		TraitManager.STAGE_PARTIAL:
			return "~%d" % (int(round(float(value) / float(bucket))) * bucket)
		_:
			return str(value)


func _on_trait_changed(trait_name: String, new_stage: int) -> void:
	if trait_name == TraitManager.TRAIT_HEAD:
		_head_stage = new_stage


# ---- Builders ----

func _build_year_counter() -> void:
	"""The year counter IS the devolution counter. There is no separate bar:
	a normal attack costs 1 year, a skill costs its own, and hitting 0 means
	fully devolved."""
	var control: Control = $Control

	_year_label = Label.new()
	_year_label.text = "--"
	_year_label.position = Vector2(8, 20)
	_year_label.add_theme_font_override("font", COUNTER_FONT)
	_year_label.add_theme_font_size_override("font_size", 16)
	_year_label.add_theme_color_override("font_color", Color("e74c3c"))
	control.add_child(_year_label)

	_year_tag_label = Label.new()
	_year_tag_label.text = "YEARS LEFT"
	# Clear of the counter itself, which is 16px type and reaches ~x58 at four digits.
	_year_tag_label.position = Vector2(64, 25)
	_year_tag_label.add_theme_font_size_override("font_size", 7)
	_year_tag_label.add_theme_color_override("font_color", Color(0.65, 0.5, 0.5))
	control.add_child(_year_tag_label)

	# PLANNING1 section 5 settles that the era readout is logarithmic. It is a
	# display layer over the same counter, never a second source of truth.
	_countdown_label = Label.new()
	_countdown_label.text = "--"
	_countdown_label.position = Vector2(130, 25)
	_countdown_label.add_theme_font_override("font", COUNTER_FONT)
	_countdown_label.add_theme_font_size_override("font_size", 8)
	_countdown_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	control.add_child(_countdown_label)


func _build_run_info() -> void:
	var control: Control = $Control

	_wave_label = Label.new()
	_wave_label.text = "Wave: --"
	# The year counter above is 16px type sitting at y20, so it occupies down to ~y40.
	# This block used to start at y34 and collide with it.
	_wave_label.position = Vector2(8, 42)
	_wave_label.add_theme_font_size_override("font_size", 8)
	_wave_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	control.add_child(_wave_label)

	_kill_label = Label.new()
	_kill_label.text = "Kills: 0   Atk: 0"
	_kill_label.position = Vector2(60, 42)
	_kill_label.add_theme_font_size_override("font_size", 8)
	_kill_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	control.add_child(_kill_label)

	_time_label = Label.new()
	_time_label.text = "0:00"
	_time_label.position = Vector2(8, 52)
	_time_label.add_theme_font_size_override("font_size", 8)
	_time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	control.add_child(_time_label)

	_buff_label = Label.new()
	_buff_label.text = ""
	_buff_label.position = Vector2(8, 62)
	_buff_label.add_theme_font_size_override("font_size", 8)
	_buff_label.add_theme_color_override("font_color", Color("f1c40f"))
	control.add_child(_buff_label)

	# Testing flags — deliberately loud so nobody reads a rigged run as a real one.
	_god_label = Label.new()
	_god_label.text = ""
	_god_label.position = Vector2(8, 66)
	_god_label.add_theme_font_size_override("font_size", 8)
	_god_label.add_theme_color_override("font_color", Color("2ecc71"))
	control.add_child(_god_label)
	_refresh_test_banner()

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


func _refresh_test_banner() -> void:
	if not _god_label:
		return
	var modes: PackedStringArray = PackedStringArray()
	if GameState.god_mode:
		modes.append("no damage")
	if GameState.freeze_years:
		modes.append("years frozen")
	if GameState.no_skill_cooldown:
		modes.append("no cooldowns")
	if modes.is_empty():
		_god_label.visible = false
		return
	_god_label.text = "TESTING — %s" % ", ".join(modes)
	_god_label.visible = true


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
