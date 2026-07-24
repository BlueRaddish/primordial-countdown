# skill_unlock_popup.gd
# Popup that appears when a new skill is unlocked by a trait loss.
# Freezes game time while open so the player can read before choosing a slot.
extends Control

const PAUSE_ID: String = "skill_unlock"

var _pending_skill: SkillData = null
var _is_open: bool = false
var _queue: Array[SkillData] = []

var _title_label: Label
var _kind_label: Label
var _desc_label: Label
var _flavor_label: Label
var _req_label: Label
var _panel: Panel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark overlay background.
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center panel.
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(300, 176)
	_panel.position = Vector2(-150, -88)
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

	var header: Label = Label.new()
	header.text = "SKILL UNLOCKED"
	header.position = Vector2(10, 8)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color("4ecdc4"))
	_panel.add_child(header)

	_kind_label = Label.new()
	_kind_label.text = ""
	_kind_label.position = Vector2(216, 10)
	_kind_label.add_theme_font_size_override("font_size", 7)
	_kind_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(_kind_label)

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.position = Vector2(10, 28)
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.position = Vector2(10, 46)
	_desc_label.size = Vector2(280, 34)
	_desc_label.custom_minimum_size = Vector2(280, 34)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 8)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_panel.add_child(_desc_label)

	_flavor_label = Label.new()
	_flavor_label.text = ""
	_flavor_label.position = Vector2(10, 86)
	_flavor_label.size = Vector2(280, 26)
	_flavor_label.custom_minimum_size = Vector2(280, 26)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 7)
	_flavor_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
	_panel.add_child(_flavor_label)

	_req_label = Label.new()
	_req_label.text = ""
	_req_label.position = Vector2(10, 116)
	_req_label.add_theme_font_size_override("font_size", 7)
	_req_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(_req_label)

	# Assign buttons.
	_make_btn("Assign Q", Vector2(10, 142), 0)
	_make_btn("Assign E", Vector2(78, 142), 1)
	_make_btn("Assign R", Vector2(146, 142), 2)

	var dismiss: Button = Button.new()
	dismiss.text = "Later"
	dismiss.position = Vector2(214, 142)
	dismiss.custom_minimum_size = Vector2(60, 22)
	dismiss.add_theme_font_size_override("font_size", 8)
	dismiss.pressed.connect(_on_dismiss)
	_panel.add_child(dismiss)

	EventBus.skill_unlocked.connect(_on_skill_unlocked)


func _make_btn(text: String, pos: Vector2, slot_index: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(60, 22)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(_on_assign.bind(slot_index))
	_panel.add_child(btn)
	return btn


func _on_skill_unlocked(skill_resource: Resource) -> void:
	var skill: SkillData = skill_resource as SkillData
	if skill == null:
		return
	# Several skills can unlock at once (a dev click, or one loss satisfying two
	# conditions). Queue them rather than clobbering the visible one.
	if _is_open:
		_queue.append(skill)
		return
	_show(skill)


func _show(skill: SkillData) -> void:
	_pending_skill = skill
	_title_label.text = skill.skill_name
	_kind_label.text = skill.get_kind_label() + ("  MULTI" if skill.is_multi_trait() else "")
	_desc_label.text = skill.description
	_flavor_label.text = skill.flavor
	_req_label.text = "Requires: %s" % skill.get_requirement_text()
	visible = true
	_is_open = true
	GameState.push_pause(PAUSE_ID)


func _on_assign(slot_index: int) -> void:
	if _pending_skill == null:
		return
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
	_is_open = false
	GameState.pop_pause(PAUSE_ID)

	# Drain the queue one popup at a time.
	if not _queue.is_empty():
		var next: SkillData = _queue.pop_front()
		_show(next)
