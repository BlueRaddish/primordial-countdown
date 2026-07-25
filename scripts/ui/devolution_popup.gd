# devolution_popup.gd
# Presents a devolution step as a CHOICE. The player is offered a randomized set of
# traits (normally 3) and picks which one degrades a stage — PLANNING1 section 6's
# player-chosen degradation, now the standard flow. Pauses the game via GameState's
# pause refcount, so a devolution firing while the character screen is open does not
# unpause on close. A dev toggle can widen the options to every degradable trait.
extends Control

const PAUSE_ID: String = "devolution"

var _panel: Panel
var _title_label: Label
var _info_label: Label
var _detail_label: Label
var _choice_buttons: Array[Button] = []

# The traits offered this step, index-aligned with _choice_buttons.
var _pending_options: Array = []
var _is_open: bool = false

# Enough buttons for the widest case (the dev "reveal all" toggle shows every
# still-degradable trait); normal play offers devolution_choice_count of them.
const MAX_OPTION_BUTTONS: int = 7


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
	_panel.size = Vector2(300, 252)
	_panel.position = Vector2(-150, -126)
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

	# One button per offered option. Bound to the slot INDEX, not a fixed trait, so
	# each step's randomized options can be dropped straight in.
	for i: int in range(MAX_OPTION_BUTTONS):
		var btn: Button = Button.new()
		btn.position = Vector2(10, 112.0 + float(i) * 18.0)
		btn.custom_minimum_size = Vector2(280, 16)
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_option_chosen.bind(i))
		btn.visible = false
		_panel.add_child(btn)
		_choice_buttons.append(btn)


func _on_devolution_pending(options: Array, step_index: int) -> void:
	_pending_options = options
	_is_open = true

	_title_label.text = "DEVOLUTION #%d" % (step_index + 1)
	_info_label.text = "Choose what you lose:"
	_detail_label.text = "Each choice degrades that trait one stage. You cannot keep all of it — only pick the order of the fall."

	_refresh_option_buttons()

	visible = true
	GameState.push_pause(PAUSE_ID)


func _refresh_option_buttons() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	for i: int in range(_choice_buttons.size()):
		var btn: Button = _choice_buttons[i]
		if i >= _pending_options.size():
			btn.visible = false
			continue

		var tname: String = _pending_options[i] as String
		var stage: int = 0
		if trait_mgr:
			stage = trait_mgr.get_trait_stage(tname)
		var next_stage: int = mini(stage + 1, TraitManager.MAX_STAGE)

		btn.text = "%s → %s   —   %s" % [
			tname.capitalize(),
			TraitManager.STAGE_NAMES[next_stage].to_upper(),
			_consequence(tname, next_stage),
		]
		# Redder for a full loss than for a partial, so the harsher option reads.
		var col: Color = Color("f39c12") if next_stage < TraitManager.MAX_STAGE else Color("e74c3c")
		btn.add_theme_color_override("font_color", col)
		btn.disabled = false
		btn.visible = true


func _consequence(trait_name: String, next_stage: int) -> String:
	"""Short, concrete note on what this choice actually does."""
	var lost: bool = next_stage >= TraitManager.MAX_STAGE
	match trait_name:
		"arms":
			return "no attack at all" if lost else "shorter reach, less damage"
		"legs":
			return "no walking or jumping" if lost else "slower, no double jump"
		"gut":
			return "no health regen" if lost else "weaker regen"
		"lungs":
			return "swings recover ×2.2" if lost else "swings recover ×1.5"
		"eyes":
			return "near-blind (22%)" if lost else "world dims (55%)"
		"skin":
			return "no protection" if lost else "less protection"
		"head":
			return "HUD numbers hidden" if lost else "HUD numbers vague"
	return "a scaling penalty"


func _on_option_chosen(index: int) -> void:
	if index < 0 or index >= _pending_options.size():
		return
	_apply(_pending_options[index] as String)


func _apply(trait_name: String) -> void:
	# Close THIS step first. Applying can immediately owe another devolution (a big
	# year cost crossing two thresholds at once), which re-opens this popup
	# synchronously — closing after would clobber that fresh step.
	_close()
	var devo: Node = get_tree().get_first_node_in_group("devolution_system")
	var trait_mgr: TraitManager = _find_trait_manager()
	if devo:
		devo.call("apply_devolution", trait_name, trait_mgr)
	elif trait_mgr:
		trait_mgr.devolve_trait(trait_name)


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_pending_options = []
	visible = false
	GameState.pop_pause(PAUSE_ID)


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null
