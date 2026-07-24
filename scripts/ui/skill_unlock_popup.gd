# skill_unlock_popup.gd
# Popup that appears when a new skill is unlocked.
# Pauses game, shows skill info, lets player assign to Q/E/R or dismiss.
extends Control

var _pending_skill: SkillData = null
var _title_label: Label
var _desc_label: Label
var _btn_q: Button
var _btn_e: Button
var _btn_r: Button
var _btn_dismiss: Button
var _panel: Panel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Build UI programmatically.
	# Dark overlay background.
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center panel.
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(260, 140)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(260, 140)
	_panel.position = Vector2(-130, -70)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	panel_style.border_color = Color("4ecdc4")
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Title: "SKILL UNLOCKED!"
	var header: Label = Label.new()
	header.text = "SKILL UNLOCKED!"
	header.position = Vector2(10, 8)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color("4ecdc4"))
	_panel.add_child(header)

	# Skill name.
	_title_label = Label.new()
	_title_label.text = ""
	_title_label.position = Vector2(10, 28)
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(_title_label)

	# Description.
	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.position = Vector2(10, 46)
	_desc_label.size = Vector2(240, 40)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 8)
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_panel.add_child(_desc_label)

	# Assign buttons.
	_btn_q = _make_btn("Assign Q", Vector2(10, 100), 0)
	_btn_e = _make_btn("Assign E", Vector2(72, 100), 1)
	_btn_r = _make_btn("Assign R", Vector2(134, 100), 2)
	_btn_dismiss = Button.new()
	_btn_dismiss.text = "Dismiss"
	_btn_dismiss.position = Vector2(196, 100)
	_btn_dismiss.custom_minimum_size = Vector2(54, 24)
	_btn_dismiss.add_theme_font_size_override("font_size", 8)
	_btn_dismiss.pressed.connect(_on_dismiss)
	_panel.add_child(_btn_dismiss)

	EventBus.skill_unlocked.connect(_on_skill_unlocked)


func _make_btn(text: String, pos: Vector2, slot_index: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(54, 24)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(_on_assign.bind(slot_index))
	_panel.add_child(btn)
	return btn


func _on_skill_unlocked(skill_resource: Resource) -> void:
	var skill: SkillData = skill_resource as SkillData
	if skill == null:
		return
	_pending_skill = skill
	_title_label.text = skill.skill_name
	_desc_label.text = skill.description
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_assign(slot_index: int) -> void:
	if _pending_skill == null:
		return
	# Find the ability manager on the player.
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("AbilityManager"):
		var ability_mgr: AbilityManager = players[0].get_node("AbilityManager") as AbilityManager
		ability_mgr.assign_skill(slot_index, _pending_skill)
	_close()


func _on_dismiss() -> void:
	_close()


func _close() -> void:
	_pending_skill = null
	visible = false
	get_tree().paused = false
