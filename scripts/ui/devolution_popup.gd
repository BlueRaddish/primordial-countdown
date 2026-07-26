# devolution_popup.gd
# Presents a devolution step as a CHOICE. The player is offered a randomized set of
# traits (normally 3) and picks which one degrades a stage — PLANNING1 section 6's
# player-chosen degradation, now the standard flow. Pauses the game via GameState's
# pause refcount, so a devolution firing while the character screen is open does not
# unpause on close. A dev toggle can widen the options to every degradable trait.
#
# Each option is its own CARD: bordered, accented in that trait's colour, with the
# stage transition and the consequence laid out inside it. It used to be a stack of
# identical full-width buttons, which read like a settings menu — the wrong shape
# for the moment the run is actually about, where you decide what to give up.
extends Control

const UILayout := preload("res://scripts/ui/ui_layout.gd")

const PAUSE_ID: String = "devolution"

var _panel: Panel
var _title_label: Label
var _info_label: Label
var _detail_label: Label

# One card per possible option, built once and restyled per step.
var _cards: Array[Button] = []
var _card_names: Array[Label] = []
var _card_stages: Array[Label] = []
var _card_notes: Array[Label] = []

# The traits offered this step, index-aligned with _cards.
var _pending_options: Array = []
var _is_open: bool = false

# Enough cards for the widest case (the dev "reveal all" toggle shows every
# still-degradable trait); normal play offers devolution_choice_count of them.
const MAX_OPTION_BUTTONS: int = 7

# Cards are TALL and sit SIDE BY SIDE — a row of things to pick between, which is the
# shape every roguelite uses for a choose-one moment, rather than a vertical list
# that reads like a settings menu.
#
# The viewport is a fixed 640x360, so the panel and its row of cards must fit inside
# that. Card width is derived from the option count, so three cards are comfortable
# and seven (the dev "reveal all" toggle) still fit on the same row.
const PANEL_MAX_W: float = 604.0
const CARDS_TOP: float = 76.0
const CARD_H: float = 118.0
const CARD_GAP: float = 8.0
const CARD_W_MAX: float = 150.0
const SIDE_PAD: float = 12.0
const BOTTOM_PAD: float = 12.0

# Cards wrap to a second row past this many. Seven options squeezed onto one row
# leaves ~76px per card, which is narrower than the consequence text — the prose
# then overflows across its neighbours instead of wrapping. Four per row keeps every
# card wide enough to actually read.
const MAX_PER_ROW: int = 4

# Each trait gets its own accent so the three cards read as distinct things rather
# than three rows of the same thing.
const TRAIT_COLORS: Dictionary = {
	"arms": Color("e74c3c"),
	"legs": Color("3498db"),
	"gut": Color("2ecc71"),
	"lungs": Color("1abc9c"),
	"eyes": Color("9b59b6"),
	"skin": Color("f39c12"),
	"head": Color("f1c40f"),
}


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

	# Center panel. Height is set per step, since it depends on how many cards the
	# step is offering.
	_panel = Panel.new()
	# Real geometry is set per-step by _layout_cards, which depends on the option
	# count. Centring is done there via UILayout so it cannot go stale.
	UILayout.center(_panel, PANEL_MAX_W, CARDS_TOP + CARD_H + BOTTOM_PAD)
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
	_detail_label.position = Vector2(12, 48)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 8)
	_detail_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	_panel.add_child(_detail_label)

	for i: int in range(MAX_OPTION_BUTTONS):
		_build_card(i)


func _build_card(index: int) -> void:
	"""One option card. Bound to the slot INDEX, not a fixed trait, so each step's
	randomized options drop straight in."""
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(CARD_W_MAX, CARD_H)
	card.pressed.connect(_on_option_chosen.bind(index))
	card.visible = false
	_panel.add_child(card)
	_cards.append(card)

	# Labels sit on top of the button and must not swallow the click. All three are
	# centre-aligned, because a tall narrow card reads as a card rather than a row.
	var name_lbl: Label = Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	card.add_child(name_lbl)
	_card_names.append(name_lbl)

	var stage_lbl: Label = Label.new()
	stage_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.add_theme_font_size_override("font_size", 7)
	stage_lbl.add_theme_color_override("font_color", Color(0.62, 0.62, 0.7))
	card.add_child(stage_lbl)
	_card_stages.append(stage_lbl)

	var note_lbl: Label = Label.new()
	note_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.add_theme_font_size_override("font_size", 8)
	note_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	card.add_child(note_lbl)
	_card_notes.append(note_lbl)


func _card_style(accent: Color, bg: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = accent
	# A heavy top edge in the trait's colour, like the banner on a physical card.
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 4
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _on_devolution_pending(options: Array, step_index: int) -> void:
	_pending_options = options
	_is_open = true

	_title_label.text = "DEVOLUTION #%d" % (step_index + 1)
	_info_label.text = "Choose what you lose:"
	_detail_label.text = "Each choice degrades that trait one stage. You cannot keep all of it — only pick the order of the fall."

	_layout_cards()
	_refresh_cards()

	visible = true
	GameState.push_pause(PAUSE_ID)


func _layout_cards() -> void:
	"""Lay the options out as a horizontal row of tall cards, sized to fit the count.

	Card width shrinks as options are added so the row always stays inside the
	viewport: three cards get the full 150px, seven fall back to 74px each."""
	var count: int = maxi(mini(_pending_options.size(), MAX_OPTION_BUTTONS), 1)

	var cols: int = mini(count, MAX_PER_ROW)
	var rows: int = int(ceil(float(count) / float(cols)))

	var usable: float = PANEL_MAX_W - SIDE_PAD * 2.0
	var card_w: float = minf(
		(usable - CARD_GAP * float(cols - 1)) / float(cols), CARD_W_MAX
	)

	var widest_row: float = card_w * float(cols) + CARD_GAP * float(cols - 1)
	var panel_w: float = maxf(widest_row + SIDE_PAD * 2.0, 300.0)
	var panel_h: float = (
		CARDS_TOP + float(rows) * CARD_H + float(rows - 1) * CARD_GAP + BOTTOM_PAD
	)

	UILayout.center(_panel, panel_w, panel_h)

	# Header text spans whatever width the panel ended up with.
	_detail_label.size = Vector2(panel_w - 24.0, 24)
	_detail_label.custom_minimum_size = Vector2(panel_w - 24.0, 24)

	var inner: float = card_w - 12.0

	for i: int in range(_cards.size()):
		var card: Button = _cards[i]
		var row: int = i / cols
		var col: int = i % cols
		# The last row may be short, so centre each row on its own contents rather
		# than left-aligning it under a full row above.
		var in_row: int = mini(count - row * cols, cols)
		var this_row_w: float = card_w * float(in_row) + CARD_GAP * float(in_row - 1)
		var row_x: float = (panel_w - this_row_w) * 0.5

		card.position = Vector2(
			row_x + float(col) * (card_w + CARD_GAP),
			CARDS_TOP + float(row) * (CARD_H + CARD_GAP)
		)
		card.size = Vector2(card_w, CARD_H)
		card.custom_minimum_size = Vector2(card_w, CARD_H)

		# Name and stage at the top of the card, consequence filling the body.
		_card_names[i].position = Vector2(6, 8)
		_card_names[i].size = Vector2(inner, 16)
		_card_names[i].custom_minimum_size = Vector2(inner, 16)

		_card_stages[i].position = Vector2(6, 27)
		_card_stages[i].size = Vector2(inner, 12)
		_card_stages[i].custom_minimum_size = Vector2(inner, 12)

		_card_notes[i].position = Vector2(6, 48)
		_card_notes[i].size = Vector2(inner, CARD_H - 56.0)
		_card_notes[i].custom_minimum_size = Vector2(inner, CARD_H - 56.0)


func _refresh_cards() -> void:
	var trait_mgr: TraitManager = _find_trait_manager()
	for i: int in range(_cards.size()):
		var card: Button = _cards[i]
		if i >= _pending_options.size():
			card.visible = false
			continue

		var tname: String = _pending_options[i] as String
		var stage: int = 0
		if trait_mgr:
			stage = trait_mgr.get_trait_stage(tname)
		var next_stage: int = mini(stage + 1, TraitManager.MAX_STAGE)
		var is_full_loss: bool = next_stage >= TraitManager.MAX_STAGE

		var accent: Color = TRAIT_COLORS.get(tname, Color("bdc3c7"))
		# A full loss is the harsher option and says so: the card burns hotter and
		# its background carries a tint of the accent instead of being flat.
		var bg: Color = Color(0.10, 0.09, 0.12, 0.95)
		if is_full_loss:
			bg = Color(accent.r * 0.22, accent.g * 0.16, accent.b * 0.18, 0.95)

		card.add_theme_stylebox_override("normal", _card_style(accent, bg))
		card.add_theme_stylebox_override(
			"hover", _card_style(accent.lightened(0.25), bg.lightened(0.10))
		)
		card.add_theme_stylebox_override(
			"pressed", _card_style(accent.lightened(0.4), bg.lightened(0.18))
		)
		card.add_theme_stylebox_override("focus", _card_style(accent, bg))

		_card_names[i].text = tname.capitalize()
		_card_names[i].add_theme_color_override("font_color", accent)

		_card_stages[i].text = "%s → %s" % [
			TraitManager.STAGE_NAMES[stage].to_upper(),
			TraitManager.STAGE_NAMES[next_stage].to_upper(),
		]
		_card_stages[i].add_theme_color_override(
			"font_color", Color("e74c3c") if is_full_loss else Color(0.62, 0.62, 0.7)
		)

		_card_notes[i].text = _consequence(tname, next_stage)
		card.disabled = false
		card.visible = true


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
