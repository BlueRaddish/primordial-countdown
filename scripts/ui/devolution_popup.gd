# devolution_popup.gd
# Presents a devolution step. Pauses the game via GameState's pause refcount, so a
# devolution firing while the character screen is open does not unpause on close.
#
# PLANNING1 milestone 3: the degradation order is FIXED. This popup announces which
# trait is degrading and why; it does not ask. Player-chosen degradation is listed
# in PLANNING1 section 6 as a possible later addition, so it lives behind
# allow_player_choice, which the character screen's dev panel can flip.
extends Control

const PAUSE_ID: String = "devolution"

var _panel: Panel
var _title_label: Label
var _info_label: Label
var _detail_label: Label
var _continue_btn: Button
var _choice_buttons: Array[Button] = []

var _pending_trait: String = ""
var _is_open: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_ui()
	EventBus.devolution_pending.connect(_on_devolution_pending)


func _build_ui() -> void:
	# Dark overlay.
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center panel.
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(300, 230)
	_panel.position = Vector2(-150, -115)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.border_color = Color("e74c3c")
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

	_title_label = Label.new()
	_title_label.text = "DEVOLUTION"
	_title_label.position = Vector2(10, 8)
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color("e74c3c"))
	_panel.add_child(_title_label)

	_info_label = Label.new()
	_info_label.text = ""
	_info_label.position = Vector2(10, 28)
	_info_label.add_theme_font_size_override("font_size", 10)
	_info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(_info_label)

	_detail_label = Label.new()
	_detail_label.text = ""
	_detail_label.position = Vector2(10, 48)
	_detail_label.size = Vector2(280, 60)
	_detail_label.custom_minimum_size = Vector2(280, 60)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 8)
	_detail_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	_panel.add_child(_detail_label)

	# Fixed-order path: a single acknowledge button.
	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.position = Vector2(10, 196)
	_continue_btn.custom_minimum_size = Vector2(280, 22)
	_continue_btn.add_theme_font_size_override("font_size", 9)
	_continue_btn.pressed.connect(_on_continue)
	_panel.add_child(_continue_btn)

	# Player-choice path: one button per trait, hidden unless allow_player_choice.
	var trait_names: Array[String] = TraitManager.ALL_TRAITS
	for i: int in range(trait_names.size()):
		var btn: Button = Button.new()
		btn.position = Vector2(10, 108.0 + float(i) * 13.0)
		btn.custom_minimum_size = Vector2(280, 12)
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_trait_chosen.bind(trait_names[i]))
		btn.visible = false
		_panel.add_child(btn)
		_choice_buttons.append(btn)


func _on_devolution_pending(trait_name: String, step_index: int) -> void:
	_pending_trait = trait_name
	_is_open = true

	var trait_mgr: TraitManager = _find_trait_manager()
	var current_stage: int = 0
	if trait_mgr:
		current_stage = trait_mgr.get_trait_stage(trait_name)
	var next_stage: int = mini(current_stage + 1, TraitManager.MAX_STAGE)

	_title_label.text = "DEVOLUTION #%d" % (step_index + 1)

	if GameState.devolution_player_choice:
		_info_label.text = "Choose a trait to degrade:"
		_detail_label.text = "Degradation order is normally fixed. Player choice is on (dev)."
		_continue_btn.visible = false
		_refresh_choice_buttons()
		for btn: Button in _choice_buttons:
			btn.visible = true
	else:
		_info_label.text = "%s -> %s" % [
			trait_name.capitalize(),
			TraitManager.STAGE_NAMES[next_stage].to_upper(),
		]
		_detail_label.text = _describe(trait_name, next_stage)
		_continue_btn.visible = true
		for btn: Button in _choice_buttons:
			btn.visible = false

	visible = true
	GameState.push_pause(PAUSE_ID)


func _describe(trait_name: String, stage: int) -> String:
	if stage < TraitManager.MAX_STAGE:
		return "%s is degrading. A scaling penalty, and nothing in return." % trait_name.capitalize()
	return "%s is gone for good. What replaces it softens the fall — it does not reverse it." % trait_name.capitalize()


func _refresh_choice_buttons() -> void:
	var trait_names: Array[String] = TraitManager.ALL_TRAITS
	var trait_mgr: TraitManager = _find_trait_manager()

	for i: int in range(trait_names.size()):
		var tname: String = trait_names[i]
		var stage: int = 0
		if trait_mgr:
			stage = trait_mgr.get_trait_stage(tname)

		var status: String = TraitManager.STAGE_NAMES[stage]
		_choice_buttons[i].text = "%s — %s" % [tname.capitalize(), status]
		_choice_buttons[i].disabled = (stage >= TraitManager.MAX_STAGE)


func _on_continue() -> void:
	_apply(_pending_trait)


func _on_trait_chosen(trait_name: String) -> void:
	_apply(trait_name)


func _apply(trait_name: String) -> void:
	var devo: Node = get_tree().get_first_node_in_group("devolution_system")
	var trait_mgr: TraitManager = _find_trait_manager()
	if devo:
		devo.call("apply_devolution", trait_name, trait_mgr)
	elif trait_mgr:
		trait_mgr.devolve_trait(trait_name)
	_close()


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_pending_trait = ""
	visible = false
	GameState.pop_pause(PAUSE_ID)


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null
