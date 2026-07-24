# character_screen.gd
# Toggle on C key press. Pauses game when open.
# Left panel: traits with stage indicators + dev mode buttons
# Right panel: skill slots Q/E/R + available skills
extends Control

var _is_open: bool = false

# UI references built in _ready.
var _trait_rows: Array[Dictionary] = [] # [{label, stage_label, inc_btn, dec_btn}]
var _skill_slot_labels: Array[Label] = []
var _available_skills_container: VBoxContainer
var _panel: Panel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	EventBus.character_screen_toggled.connect(_on_toggle_requested)
	EventBus.trait_changed.connect(_on_trait_changed)
	EventBus.skill_assigned.connect(_on_skill_assigned)

	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_screen") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func _on_toggle_requested(_open: bool) -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	visible = true
	get_tree().paused = true
	_refresh_all()


func close() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false


func _build_ui() -> void:
	# Dark overlay.
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Main panel.
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(500, 300)
	_panel.position = Vector2(-250, -150)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
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

	# Title.
	var title: Label = Label.new()
	title.text = "CHARACTER STATUS"
	title.position = Vector2(10, 6)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("4ecdc4"))
	_panel.add_child(title)

	# Close hint.
	var close_hint: Label = Label.new()
	close_hint.text = "[C] Close"
	close_hint.position = Vector2(430, 8)
	close_hint.add_theme_font_size_override("font_size", 8)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_panel.add_child(close_hint)

	# --- Left side: Traits ---
	var traits_header: Label = Label.new()
	traits_header.text = "TRAITS"
	traits_header.position = Vector2(10, 28)
	traits_header.add_theme_font_size_override("font_size", 10)
	traits_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(traits_header)

	var dev_header: Label = Label.new()
	dev_header.text = "(DEV)"
	dev_header.position = Vector2(210, 28)
	dev_header.add_theme_font_size_override("font_size", 8)
	dev_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(dev_header)

	var trait_names: Array[String] = TraitManager.ALL_TRAITS
	for i: int in range(trait_names.size()):
		var y: float = 46.0 + float(i) * 22.0
		var tname: String = trait_names[i]

		# Trait name label.
		var name_lbl: Label = Label.new()
		name_lbl.text = tname.capitalize()
		name_lbl.position = Vector2(10, y)
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		_panel.add_child(name_lbl)

		# Stage indicator — colored blocks.
		var stage_lbl: Label = Label.new()
		stage_lbl.text = "■ ■ ■ ■ ■"
		stage_lbl.position = Vector2(80, y)
		stage_lbl.add_theme_font_size_override("font_size", 9)
		stage_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		_panel.add_child(stage_lbl)

		# Stage number.
		var num_lbl: Label = Label.new()
		num_lbl.text = "0/5"
		num_lbl.position = Vector2(170, y)
		num_lbl.add_theme_font_size_override("font_size", 8)
		num_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		_panel.add_child(num_lbl)

		# Dev buttons: + and -.
		var inc_btn: Button = Button.new()
		inc_btn.text = "+"
		inc_btn.position = Vector2(210, y - 2)
		inc_btn.custom_minimum_size = Vector2(18, 18)
		inc_btn.add_theme_font_size_override("font_size", 8)
		inc_btn.pressed.connect(_on_dev_inc.bind(tname))
		_panel.add_child(inc_btn)

		var dec_btn: Button = Button.new()
		dec_btn.text = "-"
		dec_btn.position = Vector2(232, y - 2)
		dec_btn.custom_minimum_size = Vector2(18, 18)
		dec_btn.add_theme_font_size_override("font_size", 8)
		dec_btn.pressed.connect(_on_dev_dec.bind(tname))
		_panel.add_child(dec_btn)

		_trait_rows.append({
			"name": tname,
			"stage_label": stage_lbl,
			"num_label": num_lbl,
			"inc_btn": inc_btn,
			"dec_btn": dec_btn,
		})

	# --- Right side: Skills ---
	var skills_header: Label = Label.new()
	skills_header.text = "SKILL SLOTS"
	skills_header.position = Vector2(270, 28)
	skills_header.add_theme_font_size_override("font_size", 10)
	skills_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(skills_header)

	var keys: Array[String] = ["Q", "E", "R"]
	for i: int in range(3):
		var y: float = 48.0 + float(i) * 22.0
		var slot_lbl: Label = Label.new()
		slot_lbl.text = "[%s] ---" % keys[i]
		slot_lbl.position = Vector2(270, y)
		slot_lbl.add_theme_font_size_override("font_size", 9)
		slot_lbl.add_theme_color_override("font_color", Color.WHITE)
		_panel.add_child(slot_lbl)
		_skill_slot_labels.append(slot_lbl)

	# Available skills section.
	var avail_header: Label = Label.new()
	avail_header.text = "AVAILABLE SKILLS"
	avail_header.position = Vector2(270, 120)
	avail_header.add_theme_font_size_override("font_size", 9)
	avail_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_panel.add_child(avail_header)

	# Scrollable list of available skills with assign buttons.
	_available_skills_container = VBoxContainer.new()
	_available_skills_container.position = Vector2(270, 138)
	_available_skills_container.size = Vector2(220, 150)
	_panel.add_child(_available_skills_container)


func _refresh_all() -> void:
	_refresh_traits()
	_refresh_skills()


func _refresh_traits() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	if not trait_mgr:
		return

	for row: Dictionary in _trait_rows:
		var tname: String = row["name"] as String
		var stage: int = trait_mgr.get_trait_stage(tname)
		var max_s: int = TraitManager.MAX_STAGE

		# Update stage blocks — filled vs empty.
		var blocks: String = ""
		for s: int in range(max_s):
			if s < stage:
				blocks += "■ "
			else:
				blocks += "□ "
		var stage_lbl: Label = row["stage_label"] as Label
		stage_lbl.text = blocks.strip_edges()

		# Color: green → yellow → red as stage increases.
		var t: float = float(stage) / float(max_s)
		var col: Color = Color(0.3, 0.8, 0.3).lerp(Color(0.9, 0.2, 0.2), t)
		if stage >= max_s:
			col = Color(0.6, 0.1, 0.1)
		stage_lbl.add_theme_color_override("font_color", col)

		var num_lbl: Label = row["num_label"] as Label
		if stage >= max_s:
			num_lbl.text = "EXTINCT"
			num_lbl.add_theme_color_override("font_color", Color("e74c3c"))
		else:
			num_lbl.text = "%d/%d" % [stage, max_s]
			num_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

		# Dev buttons: disable at bounds.
		var inc_btn: Button = row["inc_btn"] as Button
		var dec_btn: Button = row["dec_btn"] as Button
		inc_btn.disabled = (stage >= max_s)
		dec_btn.disabled = (stage <= 0)


func _refresh_skills() -> void:
	var ability_mgr: AbilityManager = _find_ability_manager()
	if not ability_mgr:
		return

	var keys: Array[String] = ["Q", "E", "R"]
	for i: int in range(3):
		var skill: SkillData = ability_mgr.get_skill_in_slot(i)
		if skill:
			_skill_slot_labels[i].text = "[%s] %s" % [keys[i], skill.skill_name]
			_skill_slot_labels[i].add_theme_color_override("font_color", skill.aoe_color)
		else:
			_skill_slot_labels[i].text = "[%s] ---" % keys[i]
			_skill_slot_labels[i].add_theme_color_override("font_color", Color.WHITE)

	# Rebuild available skills list.
	for child: Node in _available_skills_container.get_children():
		child.queue_free()

	for skill: SkillData in ability_mgr.available_skills:
		var hbox: HBoxContainer = HBoxContainer.new()

		var lbl: Label = Label.new()
		lbl.text = skill.skill_name
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", skill.aoe_color)
		lbl.custom_minimum_size = Vector2(100, 16)
		hbox.add_child(lbl)

		for i: int in range(3):
			var btn: Button = Button.new()
			btn.text = keys[i]
			btn.custom_minimum_size = Vector2(22, 16)
			btn.add_theme_font_size_override("font_size", 7)
			btn.pressed.connect(_on_assign_skill.bind(i, skill))
			hbox.add_child(btn)

		_available_skills_container.add_child(hbox)


func _on_trait_changed(_trait_name: String, _new_stage: int) -> void:
	if _is_open:
		_refresh_all()


func _on_skill_assigned(_slot_index: int, _skill_data: Resource) -> void:
	if _is_open:
		_refresh_skills()


func _on_dev_inc(trait_name: String) -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	if trait_mgr:
		trait_mgr.devolve_trait(trait_name)
		_refresh_all()


func _on_dev_dec(trait_name: String) -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	if trait_mgr:
		var current: int = trait_mgr.get_trait_stage(trait_name)
		if current > 0:
			trait_mgr.set_trait_stage(trait_name, current - 1)
		_refresh_all()


func _on_assign_skill(slot_index: int, skill: SkillData) -> void:
	var ability_mgr: AbilityManager = _find_ability_manager()
	if ability_mgr:
		ability_mgr.assign_skill(slot_index, skill)
		_refresh_skills()


func _find_trait_manager() -> TraitManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("TraitManager"):
		return players[0].get_node("TraitManager") as TraitManager
	return null


func _find_ability_manager() -> AbilityManager:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("AbilityManager"):
		return players[0].get_node("AbilityManager") as AbilityManager
	return null
