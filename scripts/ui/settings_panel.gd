# settings_panel.gd
# The settings screen. Reachable from the main menu and the pause menu.
#
# Scope follows what a small 2D action roguelike actually needs — the set common to
# Celeste, Dead Cells and Hades — rather than a full options suite:
#
#   DISPLAY        fullscreen, vsync
#   AUDIO          master / music / SFX
#   ACCESSIBILITY  reduce flashing, screen shake
#   CONTROLS       a reference list (rebinding is not built yet)
#   ADVANCED       developer tools toggle
#
# "Reduce flashing" is the one that is not optional for this game specifically: every
# enemy telegraph, the boss slam windup and the invincibility state are all rapidly
# pulsing sprite colours. That is a photosensitivity hazard and it is also simply
# harder to read. With it on those become steady colours — the information stays, the
# strobe goes.
#
# Built in code like the rest of the UI so it stays in one file and cannot drift from
# the 640x360 viewport budget.
class_name SettingsPanel
extends Control

const UILayout := preload("res://scripts/ui/ui_layout.gd")

const PAUSE_ID: String = "settings"

const PANEL_W: float = 460.0
const PANEL_H: float = 330.0
const ROW_H: float = 20.0
const LABEL_X: float = 16.0
const CTRL_X: float = 210.0
const CTRL_W: float = 230.0

var _panel: Panel
var _rows_y: float = 0.0
var _holds_pause: bool = false

var _fullscreen_btn: Button
var _vsync_btn: Button
var _flash_btn: Button
var _shake_btn: Button
var _dev_btn: Button
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("settings_panel")
	_build_ui()
	_apply_all()
	_refresh()


func _apply_all() -> void:
	"""Push the stored settings into the engine on startup, so what the panel shows
	is what is actually in effect rather than only what was last clicked."""
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if GameState.vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	_apply_bus("Master", GameState.master_volume)
	_apply_bus("Music", GameState.music_volume)
	_apply_bus("SFX", GameState.sfx_volume)


# ---- Build ----

func _build_ui() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_panel = Panel.new()
	UILayout.center(_panel, PANEL_W, PANEL_H)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
	style.border_color = Color("4ecdc4")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var title: Label = Label.new()
	title.text = "SETTINGS"
	title.position = Vector2(LABEL_X, 8)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("4ecdc4"))
	_panel.add_child(title)

	_rows_y = 32.0

	_section("DISPLAY")
	_fullscreen_btn = _toggle_row("Fullscreen", _on_fullscreen)
	_vsync_btn = _toggle_row("VSync", _on_vsync)

	_section("AUDIO")
	_master_slider = _slider_row("Master", _on_master)
	_music_slider = _slider_row("Music", _on_music)
	_sfx_slider = _slider_row("Sound effects", _on_sfx)

	_section("ACCESSIBILITY")
	_flash_btn = _toggle_row("Reduce flashing", _on_flash)
	_shake_btn = _toggle_row("Screen shake", _on_shake)

	_section("ADVANCED")
	_dev_btn = _toggle_row("Developer tools", _on_dev)

	# Controls reference, in the space to the right of nothing — put at the bottom.
	var controls: Label = Label.new()
	controls.text = "Move WASD/arrows   Jump Space/W   Attack LMB/J   Skills Q/E/R   Interact F   Character C   Fullscreen F11   Pause Esc"
	controls.position = Vector2(LABEL_X, PANEL_H - 46.0)
	controls.size = Vector2(PANEL_W - LABEL_X * 2.0, 26)
	controls.custom_minimum_size = Vector2(PANEL_W - LABEL_X * 2.0, 26)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 7)
	controls.add_theme_color_override("font_color", Color(0.5, 0.52, 0.6))
	_panel.add_child(controls)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(PANEL_W - 96.0, 8)
	close_btn.custom_minimum_size = Vector2(80, 18)
	close_btn.add_theme_font_size_override("font_size", 8)
	close_btn.pressed.connect(close)
	_panel.add_child(close_btn)


func _section(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = Vector2(LABEL_X, _rows_y)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.85))
	_panel.add_child(lbl)
	_rows_y += 16.0


func _row_label(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = Vector2(LABEL_X + 8.0, _rows_y + 2.0)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_panel.add_child(lbl)


func _toggle_row(text: String, handler: Callable) -> Button:
	_row_label(text)
	var btn: Button = Button.new()
	btn.position = Vector2(CTRL_X, _rows_y)
	btn.custom_minimum_size = Vector2(CTRL_W, 16)
	btn.size = Vector2(CTRL_W, 16)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(handler)
	_panel.add_child(btn)
	_rows_y += ROW_H
	return btn


func _slider_row(text: String, handler: Callable) -> HSlider:
	_row_label(text)
	var slider: HSlider = HSlider.new()
	slider.position = Vector2(CTRL_X, _rows_y + 3.0)
	slider.custom_minimum_size = Vector2(CTRL_W, 12)
	slider.size = Vector2(CTRL_W, 12)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value_changed.connect(handler)
	_panel.add_child(slider)
	_rows_y += ROW_H
	return slider


# ---- Open / close ----

func open() -> void:
	visible = true
	# The in-game instance lives inside the HUD, whose year counter and skill slots
	# are created after it and so would draw straight over the panel. Siblings are
	# painted in tree order, so raising it on open is what keeps it on top.
	move_to_front()
	# Freeze the run while settings are open, the same way every other screen does.
	# Not on the main menu, where pausing the tree would stop the menu responding.
	if GameState.is_run_active and not _holds_pause:
		_holds_pause = true
		GameState.push_pause(PAUSE_ID)
	_refresh()


func close() -> void:
	visible = false
	if _holds_pause:
		_holds_pause = false
		GameState.pop_pause(PAUSE_ID)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


# ---- State ----

func _refresh() -> void:
	_set_toggle(_fullscreen_btn, _is_fullscreen())
	_set_toggle(_vsync_btn, GameState.vsync_enabled)
	_set_toggle(_flash_btn, GameState.reduce_flashing)
	_set_toggle(_shake_btn, GameState.screen_shake)
	_set_toggle(_dev_btn, GameState.show_dev_tools)
	if _master_slider:
		_master_slider.set_value_no_signal(GameState.master_volume)
	if _music_slider:
		_music_slider.set_value_no_signal(GameState.music_volume)
	if _sfx_slider:
		_sfx_slider.set_value_no_signal(GameState.sfx_volume)


func _set_toggle(btn: Button, on: bool) -> void:
	if not btn:
		return
	btn.text = "ON" if on else "OFF"
	btn.add_theme_color_override(
		"font_color", Color("2ecc71") if on else Color(0.65, 0.65, 0.72)
	)


func _is_fullscreen() -> bool:
	var wm: Node = get_node_or_null("/root/WindowManager")
	if wm and wm.has_method("is_fullscreen"):
		return wm.call("is_fullscreen")
	return false


# ---- Handlers ----

func _on_fullscreen() -> void:
	var wm: Node = get_node_or_null("/root/WindowManager")
	if wm and wm.has_method("toggle_fullscreen"):
		wm.call("toggle_fullscreen")
	_refresh()


func _on_vsync() -> void:
	GameState.vsync_enabled = not GameState.vsync_enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if GameState.vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	_refresh()


func _on_flash() -> void:
	GameState.reduce_flashing = not GameState.reduce_flashing
	_refresh()


func _on_shake() -> void:
	GameState.screen_shake = not GameState.screen_shake
	_refresh()


func _on_dev() -> void:
	GameState.show_dev_tools = not GameState.show_dev_tools
	_refresh()


func _on_master(value: float) -> void:
	GameState.master_volume = value
	_apply_bus("Master", value)


func _on_music(value: float) -> void:
	GameState.music_volume = value
	_apply_bus("Music", value)


func _on_sfx(value: float) -> void:
	GameState.sfx_volume = value
	_apply_bus("SFX", value)


func _apply_bus(bus_name: String, value: float) -> void:
	"""Set a bus's volume. Master / Music / SFX come from default_bus_layout.tres; the
	Master fallback keeps this working if that layout ever goes missing."""
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	# Silence is -80dB rather than linear_to_db(0), which is -inf.
	var db: float = -80.0 if value <= 0.001 else linear_to_db(value)
	AudioServer.set_bus_volume_db(idx, db)
