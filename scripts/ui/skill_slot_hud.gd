# skill_slot_hud.gd
# Shows Q / E / R skill slots at the bottom-left of the HUD.
# Each slot shows skill name + cooldown overlay. Empty slots show as dashed outline.
extends Control

var _slot_labels: Array[Label] = []
var _cooldown_overlays: Array[ColorRect] = []
var _key_labels: Array[Label] = []


func _ready() -> void:
	# Build 3 slot displays for Q, E, R.
	var keys: Array[String] = ["Q", "E", "R"]
	for i: int in range(3):
		var slot_panel: Panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(48, 32)
		slot_panel.position = Vector2(float(i) * 52.0, 0.0)
		slot_panel.size = Vector2(48, 32)

		# Style: dark background with subtle border.
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
		style.border_color = Color(0.4, 0.4, 0.5, 0.6)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
		slot_panel.add_theme_stylebox_override("panel", style)
		add_child(slot_panel)

		# Key label (Q/E/R) at top-left.
		var key_lbl: Label = Label.new()
		key_lbl.text = keys[i]
		key_lbl.position = Vector2(2, 0)
		key_lbl.add_theme_font_size_override("font_size", 8)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		slot_panel.add_child(key_lbl)
		_key_labels.append(key_lbl)

		# Skill name label.
		var name_lbl: Label = Label.new()
		name_lbl.text = "---"
		name_lbl.position = Vector2(2, 12)
		name_lbl.size = Vector2(44, 18)
		name_lbl.add_theme_font_size_override("font_size", 7)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		name_lbl.clip_text = true
		slot_panel.add_child(name_lbl)
		_slot_labels.append(name_lbl)

		# Cooldown overlay (fills downward).
		var cd_rect: ColorRect = ColorRect.new()
		cd_rect.color = Color(0.0, 0.0, 0.0, 0.5)
		cd_rect.position = Vector2(0, 0)
		cd_rect.size = Vector2(48, 0)
		cd_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(cd_rect)
		_cooldown_overlays.append(cd_rect)

	EventBus.skill_assigned.connect(_on_skill_assigned)


func _process(_delta: float) -> void:
	# Update cooldown overlays.
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]
	if not player.has_node("AbilityManager"):
		return
	var ability_mgr: AbilityManager = player.get_node("AbilityManager") as AbilityManager
	if not ability_mgr:
		return

	for i: int in range(3):
		var frac: float = ability_mgr.get_cooldown_fraction(i)
		_cooldown_overlays[i].size.y = 32.0 * frac


func _on_skill_assigned(slot_index: int, skill_data: Resource) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	if skill_data == null:
		_slot_labels[slot_index].text = "---"
	else:
		var skill: SkillData = skill_data as SkillData
		_slot_labels[slot_index].text = skill.skill_name


func update_slot(slot_index: int, skill: SkillData) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	if skill == null:
		_slot_labels[slot_index].text = "---"
	else:
		_slot_labels[slot_index].text = skill.skill_name
