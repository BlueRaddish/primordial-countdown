# character_screen.gd
# Toggle on C key press. Freezes game time while open, so choosing a devolution or
# reassigning skills is never a rushed decision.
#
# Left panel:  traits with stage indicators + dev +/- buttons
# Right panel: skill slots Q/E/R + available skills with assign buttons
# Bottom:      dev toggles (take no damage, player-chosen devolution)
extends Control

const PAUSE_ID: String = "character_screen"

var _is_open: bool = false

# UI references built in _ready.
var _trait_rows: Array[Dictionary] = []
var _skill_slot_labels: Array[Label] = []
var _available_skills_container: VBoxContainer
var _panel: Panel
var _god_mode_btn: Button
var _no_cooldown_btn: Button
var _freeze_years_btn: Button
var _choice_mode_btn: Button
var _skill_detail_label: Label
var _evolved_container: VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	EventBus.character_screen_toggled.connect(_on_toggle_requested)
	EventBus.trait_changed.connect(_on_trait_changed)
	EventBus.skill_assigned.connect(_on_skill_assigned)
	EventBus.evolved_trait_grown.connect(_on_evolved_changed)

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
	if _is_open:
		return
	_is_open = true
	visible = true
	# Freeze game time. Nothing ticks while the player is reading.
	GameState.push_pause(PAUSE_ID)
	_refresh_all()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	GameState.pop_pause(PAUSE_ID)


func _build_ui() -> void:
	# Dark overlay.
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Main panel.
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	# Tall enough for the full evolved roster (six forms, four slots) listed below the
	# skills. Every child is positioned from the panel's top-left, so growing it only
	# ever adds room at the bottom.
	_panel.size = Vector2(540, 400)
	_panel.position = Vector2(-270, -200)
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

	var paused_hint: Label = Label.new()
	paused_hint.text = "— time frozen —"
	paused_hint.position = Vector2(148, 9)
	paused_hint.add_theme_font_size_override("font_size", 8)
	paused_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	_panel.add_child(paused_hint)

	# Close hint.
	var close_hint: Label = Label.new()
	close_hint.text = "[C] Close"
	close_hint.position = Vector2(470, 8)
	close_hint.add_theme_font_size_override("font_size", 8)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_panel.add_child(close_hint)

	_build_trait_panel()
	_build_skill_panel()
	_build_evolved_panel()
	_build_dev_panel()


func _build_trait_panel() -> void:
	var traits_header: Label = Label.new()
	traits_header.text = "TRAITS"
	traits_header.position = Vector2(10, 28)
	traits_header.add_theme_font_size_override("font_size", 10)
	traits_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(traits_header)

	var dev_header: Label = Label.new()
	dev_header.text = "(DEV)"
	dev_header.position = Vector2(190, 29)
	dev_header.add_theme_font_size_override("font_size", 8)
	dev_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(dev_header)

	var trait_names: Array[String] = TraitManager.ALL_TRAITS
	for i: int in range(trait_names.size()):
		var y: float = 46.0 + float(i) * 22.0
		var tname: String = trait_names[i]

		var name_lbl: Label = Label.new()
		name_lbl.text = tname.capitalize()
		name_lbl.position = Vector2(10, y)
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		_panel.add_child(name_lbl)

		# Stage indicator — one block per degradation step.
		var stage_lbl: Label = Label.new()
		stage_lbl.text = "□ □"
		stage_lbl.position = Vector2(70, y)
		stage_lbl.add_theme_font_size_override("font_size", 9)
		stage_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		_panel.add_child(stage_lbl)

		var num_lbl: Label = Label.new()
		num_lbl.text = "Intact"
		num_lbl.position = Vector2(110, y)
		num_lbl.add_theme_font_size_override("font_size", 8)
		num_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		_panel.add_child(num_lbl)

		var inc_btn: Button = Button.new()
		inc_btn.text = "+"
		inc_btn.position = Vector2(190, y - 2)
		inc_btn.custom_minimum_size = Vector2(18, 18)
		inc_btn.add_theme_font_size_override("font_size", 8)
		inc_btn.pressed.connect(_on_dev_inc.bind(tname))
		_panel.add_child(inc_btn)

		var dec_btn: Button = Button.new()
		dec_btn.text = "-"
		dec_btn.position = Vector2(212, y - 2)
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


func _build_skill_panel() -> void:
	var skills_header: Label = Label.new()
	skills_header.text = "SKILL SLOTS"
	skills_header.position = Vector2(250, 28)
	skills_header.add_theme_font_size_override("font_size", 10)
	skills_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_panel.add_child(skills_header)

	var keys: Array[String] = ["Q", "E", "R"]
	for i: int in range(3):
		var slot_lbl: Label = Label.new()
		slot_lbl.text = "[%s] ---" % keys[i]
		slot_lbl.position = Vector2(250.0 + float(i) * 96.0, 46.0)
		slot_lbl.add_theme_font_size_override("font_size", 9)
		slot_lbl.add_theme_color_override("font_color", Color.WHITE)
		_panel.add_child(slot_lbl)
		_skill_slot_labels.append(slot_lbl)

	var avail_header: Label = Label.new()
	avail_header.text = "AVAILABLE SKILLS"
	avail_header.position = Vector2(250, 68)
	avail_header.add_theme_font_size_override("font_size", 9)
	avail_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_panel.add_child(avail_header)

	var avail_hint: Label = Label.new()
	avail_hint.text = "(granted by lost traits)"
	avail_hint.position = Vector2(360, 69)
	avail_hint.add_theme_font_size_override("font_size", 7)
	avail_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(avail_hint)

	_available_skills_container = VBoxContainer.new()
	_available_skills_container.position = Vector2(250, 84)
	_available_skills_container.size = Vector2(280, 160)
	_available_skills_container.add_theme_constant_override("separation", 1)
	_panel.add_child(_available_skills_container)

	_skill_detail_label = Label.new()
	_skill_detail_label.text = ""
	_skill_detail_label.position = Vector2(250, 248)
	_skill_detail_label.size = Vector2(280, 24)
	_skill_detail_label.custom_minimum_size = Vector2(280, 24)
	_skill_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_detail_label.add_theme_font_size_override("font_size", 7)
	_skill_detail_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	_panel.add_child(_skill_detail_label)


func _build_evolved_panel() -> void:
	var header: Label = Label.new()
	header.text = "EVOLVED"
	header.position = Vector2(250, 272)
	header.add_theme_font_size_override("font_size", 9)
	header.add_theme_color_override("font_color", Color("aed6f1"))
	_panel.add_child(header)

	var hint: Label = Label.new()
	hint.text = "(grow back over a lost trait)"
	hint.position = Vector2(310, 273)
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(hint)

	_evolved_container = VBoxContainer.new()
	_evolved_container.position = Vector2(250, 286)
	_evolved_container.size = Vector2(280, 106)
	_evolved_container.add_theme_constant_override("separation", 1)
	_panel.add_child(_evolved_container)


func _build_dev_panel() -> void:
	var dev_header: Label = Label.new()
	dev_header.text = "TESTING"
	dev_header.position = Vector2(10, 208)
	dev_header.add_theme_font_size_override("font_size", 9)
	dev_header.add_theme_color_override("font_color", Color("f1c40f"))
	_panel.add_child(dev_header)

	_god_mode_btn = Button.new()
	_god_mode_btn.position = Vector2(10, 224)
	_god_mode_btn.custom_minimum_size = Vector2(220, 20)
	_god_mode_btn.add_theme_font_size_override("font_size", 8)
	_god_mode_btn.pressed.connect(_on_god_mode_pressed)
	_panel.add_child(_god_mode_btn)

	_no_cooldown_btn = Button.new()
	_no_cooldown_btn.position = Vector2(10, 246)
	_no_cooldown_btn.custom_minimum_size = Vector2(220, 20)
	_no_cooldown_btn.add_theme_font_size_override("font_size", 8)
	_no_cooldown_btn.pressed.connect(_on_no_cooldown_pressed)
	_panel.add_child(_no_cooldown_btn)

	_freeze_years_btn = Button.new()
	_freeze_years_btn.position = Vector2(10, 268)
	_freeze_years_btn.custom_minimum_size = Vector2(220, 20)
	_freeze_years_btn.add_theme_font_size_override("font_size", 8)
	_freeze_years_btn.pressed.connect(_on_freeze_years_pressed)
	_panel.add_child(_freeze_years_btn)

	_choice_mode_btn = Button.new()
	_choice_mode_btn.position = Vector2(10, 290)
	_choice_mode_btn.custom_minimum_size = Vector2(220, 20)
	_choice_mode_btn.add_theme_font_size_override("font_size", 8)
	_choice_mode_btn.pressed.connect(_on_choice_mode_pressed)
	_panel.add_child(_choice_mode_btn)

	var reset_btn: Button = Button.new()
	reset_btn.text = "Reset all traits to intact"
	reset_btn.position = Vector2(10, 312)
	reset_btn.custom_minimum_size = Vector2(220, 20)
	reset_btn.add_theme_font_size_override("font_size", 8)
	reset_btn.pressed.connect(_on_reset_traits)
	_panel.add_child(reset_btn)


func _refresh_all() -> void:
	_refresh_traits()
	_refresh_skills()
	_refresh_evolved()
	_refresh_dev_toggles()


func _refresh_evolved() -> void:
	if not _evolved_container:
		return
	for child: Node in _evolved_container.get_children():
		child.queue_free()

	var mgr: Node = _find_evolved_manager()
	if not mgr:
		return

	var defs: Array = mgr.get("definitions")
	var any: bool = false
	for data: EvolvedTraitData in defs:
		var grown: bool = mgr.call("has_trait", data.id)
		var eligible: bool = mgr.call("is_eligible", data.id)
		# A form whose slot was taken by a rival is listed too, greyed out — the
		# choice that closed it off should stay visible for the rest of the run.
		var blocker: EvolvedTraitData = mgr.call("get_blocker", data.id)
		if not grown and not eligible and blocker == null:
			continue
		any = true

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)

		var name_lbl: Label = Label.new()
		name_lbl.text = data.display_name
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override(
			"font_color", data.color if blocker == null else Color(0.4, 0.4, 0.45)
		)
		name_lbl.custom_minimum_size = Vector2(90, 14)
		hbox.add_child(name_lbl)

		if grown:
			var grown_lbl: Label = Label.new()
			grown_lbl.text = "grown"
			grown_lbl.add_theme_font_size_override("font_size", 7)
			grown_lbl.add_theme_color_override("font_color", Color("2ecc71"))
			hbox.add_child(grown_lbl)
		elif blocker != null:
			var closed_lbl: Label = Label.new()
			closed_lbl.text = "closed off by %s" % blocker.display_name
			closed_lbl.add_theme_font_size_override("font_size", 7)
			closed_lbl.add_theme_color_override("font_color", Color(0.45, 0.4, 0.4))
			hbox.add_child(closed_lbl)
		else:
			var grow_btn: Button = Button.new()
			grow_btn.text = "Grow (over %s)" % data.replaces_trait.capitalize()
			grow_btn.custom_minimum_size = Vector2(160, 14)
			grow_btn.add_theme_font_size_override("font_size", 7)
			grow_btn.pressed.connect(_on_grow_evolved.bind(data.id))
			hbox.add_child(grow_btn)

		_evolved_container.add_child(hbox)

	if not any:
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "None yet. Certain losses open older forms."
		empty_lbl.add_theme_font_size_override("font_size", 7)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_evolved_container.add_child(empty_lbl)


func _refresh_traits() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	if not trait_mgr:
		return

	for row: Dictionary in _trait_rows:
		var tname: String = row["name"] as String
		var stage: int = trait_mgr.get_trait_stage(tname)
		var max_s: int = TraitManager.MAX_STAGE

		var blocks: String = ""
		for s: int in range(max_s):
			blocks += "■ " if s < stage else "□ "
		var stage_lbl: Label = row["stage_label"] as Label
		stage_lbl.text = blocks.strip_edges()

		# Green -> yellow -> red as the trait degrades.
		var t: float = float(stage) / float(max_s)
		var col: Color = Color(0.3, 0.8, 0.3).lerp(Color(0.9, 0.2, 0.2), t)
		stage_lbl.add_theme_color_override("font_color", col)

		var num_lbl: Label = row["num_label"] as Label
		num_lbl.text = TraitManager.STAGE_NAMES[stage]
		if stage >= max_s:
			num_lbl.add_theme_color_override("font_color", Color("e74c3c"))
		elif stage > 0:
			num_lbl.add_theme_color_override("font_color", Color("f39c12"))
		else:
			num_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

		(row["inc_btn"] as Button).disabled = (stage >= max_s)
		(row["dec_btn"] as Button).disabled = (stage <= 0)


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
			_skill_slot_labels[i].add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	for child: Node in _available_skills_container.get_children():
		child.queue_free()

	if ability_mgr.available_skills.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "None yet. Skills unlock as traits are lost."
		empty_lbl.add_theme_font_size_override("font_size", 7)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_available_skills_container.add_child(empty_lbl)
		_skill_detail_label.text = ""
		return

	for skill: SkillData in ability_mgr.available_skills:
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 2)

		var kind_lbl: Label = Label.new()
		kind_lbl.text = skill.get_kind_label()
		kind_lbl.add_theme_font_size_override("font_size", 6)
		kind_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		kind_lbl.custom_minimum_size = Vector2(30, 14)
		hbox.add_child(kind_lbl)

		var lbl: Label = Label.new()
		lbl.text = skill.skill_name
		if skill.is_multi_trait():
			lbl.text += " *"
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", skill.aoe_color)
		lbl.custom_minimum_size = Vector2(110, 14)
		hbox.add_child(lbl)

		var cd_lbl: Label = Label.new()
		cd_lbl.text = "%.0fs" % skill.cooldown
		cd_lbl.add_theme_font_size_override("font_size", 6)
		cd_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		cd_lbl.custom_minimum_size = Vector2(18, 14)
		hbox.add_child(cd_lbl)

		var cost_lbl: Label = Label.new()
		cost_lbl.text = skill.get_cost_label()
		cost_lbl.add_theme_font_size_override("font_size", 6)
		cost_lbl.add_theme_color_override(
			"font_color", Color(0.4, 0.75, 0.45) if skill.year_cost <= 0.0 else Color("e08b6b")
		)
		cost_lbl.custom_minimum_size = Vector2(26, 14)
		hbox.add_child(cost_lbl)

		for i: int in range(3):
			var btn: Button = Button.new()
			btn.text = ["Q", "E", "R"][i]
			btn.custom_minimum_size = Vector2(20, 14)
			btn.add_theme_font_size_override("font_size", 7)
			btn.pressed.connect(_on_assign_skill.bind(i, skill))
			btn.mouse_entered.connect(_on_skill_hovered.bind(skill))
			hbox.add_child(btn)

		_available_skills_container.add_child(hbox)

	_skill_detail_label.text = "* = multi-trait. Costs are years off the countdown; a normal attack costs 1."


func _refresh_dev_toggles() -> void:
	if _god_mode_btn:
		_god_mode_btn.text = "Take no damage: %s" % ("ON" if GameState.god_mode else "OFF")
		var col: Color = Color("2ecc71") if GameState.god_mode else Color(0.7, 0.7, 0.8)
		_god_mode_btn.add_theme_color_override("font_color", col)
	if _no_cooldown_btn:
		_no_cooldown_btn.text = "Zero skill cooldown: %s" % (
			"ON" if GameState.no_skill_cooldown else "OFF"
		)
		var cd_col: Color = Color("2ecc71") if GameState.no_skill_cooldown else Color(0.7, 0.7, 0.8)
		_no_cooldown_btn.add_theme_color_override("font_color", cd_col)
	if _freeze_years_btn:
		_freeze_years_btn.text = "Freeze year counter: %s" % (
			"ON" if GameState.freeze_years else "OFF"
		)
		var fy_col: Color = Color("2ecc71") if GameState.freeze_years else Color(0.7, 0.7, 0.8)
		_freeze_years_btn.add_theme_color_override("font_color", fy_col)
	if _choice_mode_btn:
		var mode: String = "SHOW ALL" if GameState.devolution_player_choice else "RANDOM 3"
		_choice_mode_btn.text = "Devolution options: %s" % mode


# ---- Callbacks ----

func _on_trait_changed(_trait_name: String, _new_stage: int) -> void:
	if _is_open:
		_refresh_all()


func _on_skill_assigned(_slot_index: int, _skill_data: Resource) -> void:
	if _is_open:
		_refresh_skills()


func _on_evolved_changed(_evolved_id: String) -> void:
	if _is_open:
		_refresh_all()


func _on_grow_evolved(evolved_id: String) -> void:
	var mgr: Node = _find_evolved_manager()
	if mgr:
		mgr.call("grow", evolved_id)
	_refresh_all()


func _on_skill_hovered(skill: SkillData) -> void:
	if not _skill_detail_label:
		return
	_skill_detail_label.text = "%s  —  Cost: %s  —  Requires: %s" % [
		skill.description, skill.get_cost_label(), skill.get_requirement_text()
	]


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


func _on_reset_traits() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	if trait_mgr:
		trait_mgr.reset_all()
		for tname: String in TraitManager.ALL_TRAITS:
			EventBus.trait_changed.emit(tname, 0)
	var evolved_mgr: Node = _find_evolved_manager()
	if evolved_mgr:
		evolved_mgr.call("reset_all")
	_refresh_all()


func _on_god_mode_pressed() -> void:
	GameState.toggle_god_mode()
	_refresh_dev_toggles()


func _on_no_cooldown_pressed() -> void:
	GameState.set_no_skill_cooldown(not GameState.no_skill_cooldown)
	_refresh_dev_toggles()


func _on_freeze_years_pressed() -> void:
	GameState.set_freeze_years(not GameState.freeze_years)
	_refresh_dev_toggles()


func _on_choice_mode_pressed() -> void:
	GameState.devolution_player_choice = not GameState.devolution_player_choice
	_refresh_dev_toggles()


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


func _find_evolved_manager() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("EvolvedTraitManager"):
		return players[0].get_node("EvolvedTraitManager")
	return null
