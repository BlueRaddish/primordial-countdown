# evolved_trait_popup.gd
# The hidden evolved-trait offer. Surfaces when a specific combination of losses is
# reached (EventBus.evolved_trait_available) and asks the player to grow the trait
# or leave it. Freezes game time while open, like every other decision screen.
#
# Accepting grows the trait, which permanently takes over the slot of the trait it
# replaces. Declining resumes normal degradation; the offer stays claimable later
# from the character screen for as long as the combo holds.
extends Control

const UILayout := preload("res://scripts/ui/ui_layout.gd")

const PAUSE_ID: String = "evolved_trait"

var _panel: Panel
var _title_label: Label
var _name_label: Label
var _desc_label: Label
var _flavor_label: Label
var _replaces_label: Label

var _pending: EvolvedTraitData = null
var _queue: Array[EvolvedTraitData] = []
var _is_open: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.evolved_trait_available.connect(_on_available)


func _build_ui() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_panel = Panel.new()
	UILayout.center(_panel, 320, 210)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.08, 0.96)
	style.border_color = Color("aed6f1")
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
	_title_label.text = "SOMETHING GROWS BACK"
	_title_label.position = Vector2(10, 8)
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color("aed6f1"))
	_panel.add_child(_title_label)

	_name_label = Label.new()
	_name_label.text = ""
	_name_label.position = Vector2(10, 30)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.position = Vector2(10, 52)
	_desc_label.size = Vector2(300, 40)
	_desc_label.custom_minimum_size = Vector2(300, 40)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 10)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_panel.add_child(_desc_label)

	_flavor_label = Label.new()
	_flavor_label.text = ""
	_flavor_label.position = Vector2(10, 96)
	_flavor_label.size = Vector2(300, 34)
	_flavor_label.custom_minimum_size = Vector2(300, 34)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 9)
	_flavor_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.62))
	_panel.add_child(_flavor_label)

	_replaces_label = Label.new()
	_replaces_label.text = ""
	_replaces_label.position = Vector2(10, 132)
	_replaces_label.size = Vector2(300, 32)
	_replaces_label.custom_minimum_size = Vector2(300, 32)
	_replaces_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_replaces_label.add_theme_font_size_override("font_size", 9)
	_replaces_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	_panel.add_child(_replaces_label)

	var grow_btn: Button = Button.new()
	grow_btn.text = "Let it grow"
	grow_btn.position = Vector2(10, 168)
	grow_btn.custom_minimum_size = Vector2(150, 26)
	grow_btn.add_theme_font_size_override("font_size", 11)
	grow_btn.pressed.connect(_on_grow)
	_panel.add_child(grow_btn)

	var decline_btn: Button = Button.new()
	decline_btn.text = "Not yet"
	decline_btn.position = Vector2(168, 168)
	decline_btn.custom_minimum_size = Vector2(142, 26)
	decline_btn.add_theme_font_size_override("font_size", 11)
	decline_btn.pressed.connect(_on_decline)
	_panel.add_child(decline_btn)


func _on_available(evolved_resource: Resource) -> void:
	var data: EvolvedTraitData = evolved_resource as EvolvedTraitData
	if data == null:
		return
	if _is_open:
		_queue.append(data)
		return
	_show(data)


func _show(data: EvolvedTraitData) -> void:
	_pending = data
	_name_label.text = data.display_name
	_name_label.add_theme_color_override("font_color", data.color)
	_desc_label.text = data.description
	_flavor_label.text = data.flavor
	_replaces_label.text = _build_commitment_text(data)
	visible = true
	_is_open = true
	GameState.push_pause(PAUSE_ID)


func _build_commitment_text(data: EvolvedTraitData) -> String:
	"""Spell out the cost of accepting. A slot only ever holds one evolved trait, so
	taking this one ends every other path out of that slot for the rest of the run —
	the player should be told that before they commit, not discover it later."""
	var text: String = "Grows from your %s and takes over that slot. Permanent." % (
		data.replaces_trait.capitalize()
	)
	var mgr: Node = _find_evolved_manager()
	if not mgr:
		return text
	var names: PackedStringArray = PackedStringArray()
	for rival: EvolvedTraitData in mgr.call("get_rivals", data.id):
		names.append(rival.display_name)
	if names.size() > 0:
		text += "\nTaking it closes off: %s." % ", ".join(names)
	return text


func _on_grow() -> void:
	if _pending:
		var mgr: Node = _find_evolved_manager()
		if mgr:
			mgr.call("grow", _pending.id)
	_close()


func _on_decline() -> void:
	if _pending:
		var mgr: Node = _find_evolved_manager()
		if mgr:
			mgr.call("decline", _pending.id)
	_close()


func _close() -> void:
	_pending = null
	visible = false
	_is_open = false
	GameState.pop_pause(PAUSE_ID)
	if not _queue.is_empty():
		_show(_queue.pop_front())


func _find_evolved_manager() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("EvolvedTraitManager"):
		return players[0].get_node("EvolvedTraitManager")
	return null
