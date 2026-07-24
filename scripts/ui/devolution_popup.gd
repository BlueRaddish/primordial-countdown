# devolution_popup.gd
# Popup that appears when a devolution milestone is reached.
# Pauses game, shows trait selection buttons for the player to pick which trait to degrade.
extends Control

var _buttons: Array[Button] = []
var _panel: Panel
var _title_label: Label
var _info_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark overlay.
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center panel.
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(300, 220)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(300, 220)
	_panel.position = Vector2(-150, -110)
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

	# Title.
	_title_label = Label.new()
	_title_label.text = "DEVOLUTION"
	_title_label.position = Vector2(10, 8)
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color("e74c3c"))
	_panel.add_child(_title_label)

	# Info.
	_info_label = Label.new()
	_info_label.text = "Choose a trait to degrade:"
	_info_label.position = Vector2(10, 28)
	_info_label.add_theme_font_size_override("font_size", 9)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_panel.add_child(_info_label)

	# Trait buttons — built once, updated each time the popup opens.
	var trait_names: Array[String] = TraitManager.ALL_TRAITS
	for i: int in range(trait_names.size()):
		var btn: Button = Button.new()
		btn.position = Vector2(10, 48 + float(i) * 24.0)
		btn.custom_minimum_size = Vector2(280, 20)
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_trait_selected.bind(trait_names[i]))
		_panel.add_child(btn)
		_buttons.append(btn)

	EventBus.devolution_milestone_reached.connect(_on_milestone)


func _on_milestone(_kill_count: int) -> void:
	_refresh_buttons()
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _refresh_buttons() -> void:
	var trait_names: Array[String] = TraitManager.ALL_TRAITS
	var trait_mgr: TraitManager = _find_trait_manager()

	for i: int in range(trait_names.size()):
		var tname: String = trait_names[i]
		var stage: int = 0
		if trait_mgr:
			stage = trait_mgr.get_trait_stage(tname)

		var status: String = "Stage %d/%d" % [stage, TraitManager.MAX_STAGE]
		if stage >= TraitManager.MAX_STAGE:
			status = "EXTINCT"

		_buttons[i].text = "%s — %s" % [tname.capitalize(), status]
		_buttons[i].disabled = (stage >= TraitManager.MAX_STAGE)


func _on_trait_selected(trait_name: String) -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	if trait_mgr:
		trait_mgr.devolve_trait(trait_name)
	_close()


func _close() -> void:
	visible = false
	get_tree().paused = false


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null
