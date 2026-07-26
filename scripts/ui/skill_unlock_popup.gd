# skill_unlock_popup.gd
# The loadout editor, opened when a trait loss grants a new skill. Freezes game time.
#
# This used to be an overwrite prompt: it showed the new skill and three "Assign Q/E/R"
# buttons, with no indication of what was already in those slots — so taking a new
# skill meant blindly destroying one you could not see. It is now a real editor:
#
#   * the three slots show what they currently hold,
#   * every unlocked skill is listed and selectable, not just the new one,
#   * you can rearrange as much as you like while it is open.
#
# Learning a skill is the one moment the loadout is unlocked (see AbilityManager), so
# this screen IS that window. Closing it locks the loadout again, which is what stops
# the character screen being a free mid-fight loadout swap.
extends Control

const UILayout := preload("res://scripts/ui/ui_layout.gd")

const PAUSE_ID: String = "skill_unlock"

const PANEL_W: float = 600.0
const PANEL_H: float = 330.0
const COL_L: float = 14.0
const COL_R: float = 268.0
const COL_R_W: float = 318.0
const SLOT_KEYS: Array[String] = ["Q", "E", "R"]

var _pending_skill: SkillData = null
var _selected: SkillData = null
var _is_open: bool = false
var _queue: Array[SkillData] = []

var _panel: Panel
var _new_name_label: Label
var _new_kind_label: Label
var _desc_label: Label
var _flavor_label: Label
var _req_label: Label
var _slot_buttons: Array[Button] = []
var _slot_clear_buttons: Array[Button] = []
var _list_container: VBoxContainer
var _hint_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.skill_unlocked.connect(_on_skill_unlocked)


# ---- Build ----

func _build_ui() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_panel = Panel.new()
	UILayout.center(_panel, PANEL_W, PANEL_H)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.11, 0.97)
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

	var header: Label = Label.new()
	header.text = "SKILL UNLOCKED — EDIT LOADOUT"
	header.position = Vector2(COL_L, 8)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color("4ecdc4"))
	_panel.add_child(header)

	_build_new_skill_card()
	_build_slots()
	_build_list()

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.position = Vector2(COL_L, PANEL_H - 30.0)
	_hint_label.size = Vector2(PANEL_W - 130.0, 22)
	_hint_label.custom_minimum_size = Vector2(PANEL_W - 130.0, 22)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 7)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_panel.add_child(_hint_label)

	var done: Button = Button.new()
	done.text = "Done"
	done.position = Vector2(PANEL_W - 104.0, PANEL_H - 32.0)
	done.custom_minimum_size = Vector2(90, 22)
	done.add_theme_font_size_override("font_size", 9)
	done.pressed.connect(_on_done)
	_panel.add_child(done)


func _build_new_skill_card() -> void:
	var tag: Label = Label.new()
	tag.text = "NEW"
	tag.position = Vector2(COL_L, 30)
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Color("f1c40f"))
	_panel.add_child(tag)

	_new_name_label = Label.new()
	_new_name_label.position = Vector2(COL_L + 32.0, 28)
	_new_name_label.add_theme_font_size_override("font_size", 11)
	_panel.add_child(_new_name_label)

	_new_kind_label = Label.new()
	_new_kind_label.position = Vector2(COL_L, 48)
	_new_kind_label.add_theme_font_size_override("font_size", 7)
	_new_kind_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	_panel.add_child(_new_kind_label)

	_desc_label = Label.new()
	_desc_label.position = Vector2(COL_L, 66)
	_desc_label.size = Vector2(238, 60)
	_desc_label.custom_minimum_size = Vector2(238, 60)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 8)
	_desc_label.add_theme_color_override("font_color", Color(0.86, 0.86, 0.92))
	_panel.add_child(_desc_label)

	_flavor_label = Label.new()
	_flavor_label.position = Vector2(COL_L, 132)
	_flavor_label.size = Vector2(238, 46)
	_flavor_label.custom_minimum_size = Vector2(238, 46)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 7)
	_flavor_label.add_theme_color_override("font_color", Color(0.52, 0.52, 0.64))
	_panel.add_child(_flavor_label)

	_req_label = Label.new()
	_req_label.position = Vector2(COL_L, 184)
	_req_label.size = Vector2(238, 30)
	_req_label.custom_minimum_size = Vector2(238, 30)
	_req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_req_label.add_theme_font_size_override("font_size", 7)
	_req_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(_req_label)


func _build_slots() -> void:
	var head: Label = Label.new()
	head.text = "LOADOUT"
	head.position = Vector2(COL_R, 30)
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(head)

	var sub: Label = Label.new()
	sub.text = "(click a slot to put the selected skill in it)"
	sub.position = Vector2(COL_R + 60.0, 31)
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(sub)

	for i: int in range(3):
		var y: float = 46.0 + float(i) * 26.0

		var btn: Button = Button.new()
		btn.position = Vector2(COL_R, y)
		btn.custom_minimum_size = Vector2(COL_R_W - 30.0, 22)
		btn.size = Vector2(COL_R_W - 30.0, 22)
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		_panel.add_child(btn)
		_slot_buttons.append(btn)

		var clear: Button = Button.new()
		clear.text = "x"
		clear.position = Vector2(COL_R + COL_R_W - 26.0, y)
		clear.custom_minimum_size = Vector2(22, 22)
		clear.add_theme_font_size_override("font_size", 8)
		clear.pressed.connect(_on_slot_cleared.bind(i))
		_panel.add_child(clear)
		_slot_clear_buttons.append(clear)


func _build_list() -> void:
	var head: Label = Label.new()
	head.text = "ALL UNLOCKED SKILLS"
	head.position = Vector2(COL_R, 128)
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(head)

	# Scrolls: a late run can have most of the 20-skill roster unlocked at once.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(COL_R, 144)
	scroll.size = Vector2(COL_R_W, 148)
	scroll.custom_minimum_size = Vector2(COL_R_W, 148)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.custom_minimum_size = Vector2(COL_R_W - 12.0, 0)
	_list_container.add_theme_constant_override("separation", 1)
	scroll.add_child(_list_container)


# ---- Flow ----

func _on_skill_unlocked(skill_resource: Resource) -> void:
	var skill: SkillData = skill_resource as SkillData
	if skill == null:
		return
	# Several skills can unlock at once (one loss satisfying two conditions). Queue
	# them rather than clobbering the visible one.
	if _is_open:
		if not _queue.has(skill):
			_queue.append(skill)
		return
	_show(skill)


func _show(skill: SkillData) -> void:
	_pending_skill = skill
	_selected = skill

	_new_name_label.text = skill.skill_name
	_new_name_label.add_theme_color_override("font_color", skill.aoe_color)
	_new_kind_label.text = "%s   %s   cd %.0fs%s" % [
		skill.get_kind_label(), skill.get_cost_label(), skill.cooldown,
		"   MULTI" if skill.is_multi_trait() else "",
	]
	_desc_label.text = skill.description
	_flavor_label.text = skill.flavor
	_req_label.text = "Requires: %s" % skill.get_requirement_text()

	# Auto-place into a free slot so the common case needs no clicks at all.
	var mgr: AbilityManager = _find_ability_manager()
	if mgr:
		for i: int in range(3):
			if mgr.get_skill_in_slot(i) == null:
				mgr.assign_skill(i, skill)
				break

	_refresh()
	visible = true
	_is_open = true
	GameState.push_pause(PAUSE_ID)


func _refresh() -> void:
	var mgr: AbilityManager = _find_ability_manager()
	if not mgr:
		return

	for i: int in range(3):
		var held: SkillData = mgr.get_skill_in_slot(i)
		var btn: Button = _slot_buttons[i]
		if held:
			btn.text = "[%s]  %s" % [SLOT_KEYS[i], held.skill_name]
			btn.add_theme_color_override("font_color", held.aoe_color)
		else:
			btn.text = "[%s]  — empty —" % SLOT_KEYS[i]
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_slot_clear_buttons[i].disabled = held == null

	for child: Node in _list_container.get_children():
		child.queue_free()

	for skill: SkillData in mgr.available_skills:
		var row: Button = Button.new()
		var mark: String = "> " if _selected and _selected.skill_name == skill.skill_name else "   "
		var slotted: String = ""
		for i: int in range(3):
			var held2: SkillData = mgr.get_skill_in_slot(i)
			if held2 and held2.skill_name == skill.skill_name:
				slotted = "  [%s]" % SLOT_KEYS[i]
		row.text = "%s%s  (%s)%s" % [mark, skill.skill_name, skill.get_kind_label(), slotted]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(COL_R_W - 14.0, 16)
		row.add_theme_font_size_override("font_size", 7)
		row.add_theme_color_override("font_color", skill.aoe_color)
		row.pressed.connect(_on_skill_selected.bind(skill))
		_list_container.add_child(row)

	if _selected:
		_hint_label.text = "Selected: %s — %s" % [_selected.skill_name, _selected.description]
	else:
		_hint_label.text = "Pick a skill below, then click the slot to put it in."


func _on_skill_selected(skill: SkillData) -> void:
	_selected = skill
	_refresh()


func _on_slot_pressed(slot_index: int) -> void:
	if _selected == null:
		return
	var mgr: AbilityManager = _find_ability_manager()
	if mgr:
		mgr.assign_skill(slot_index, _selected)
	_refresh()


func _on_slot_cleared(slot_index: int) -> void:
	var mgr: AbilityManager = _find_ability_manager()
	if mgr:
		mgr.unassign_skill(slot_index)
	_refresh()


func _on_done() -> void:
	_close()


func _close() -> void:
	_pending_skill = null
	visible = false
	_is_open = false
	GameState.pop_pause(PAUSE_ID)

	# Drain the queue one editor at a time; only lock the loadout once the last
	# newly-learned skill has been dealt with.
	if not _queue.is_empty():
		_show(_queue.pop_front())
		return

	var mgr: AbilityManager = _find_ability_manager()
	if mgr:
		mgr.close_reassign_window()


func _find_ability_manager() -> AbilityManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("AbilityManager"):
		return players[0].get_node("AbilityManager") as AbilityManager
	return null
