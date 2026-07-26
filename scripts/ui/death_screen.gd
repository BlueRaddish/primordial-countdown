# death_screen.gd
# The ending. Freezes the run where it stopped and reports what the player actually did.
#
# There is deliberately NO victory branch. The countdown is the antagonist and it always
# wins; an ending screen that could say "you won" would be telling a different story than
# the rest of the game.
#
# The picture is the run itself — the era backdrop the player reached and their own
# devolved sprite, held still. Only return_to_menu() changes scene, so both are still
# rendered behind this layer at death time, and the tree being paused is what freezes the
# sprite mid-animation, so nothing needs explicit freezing. That is why the dimmer is thin
# (0.5) rather than the near-opaque red it used to be: it seats text on top of the frame
# instead of hiding it.
extends CanvasLayer

const PAUSE_ID: String = "death"

# Reached through preload rather than as global types on purpose. Neither is an autoload —
# TraitManager is a child of the player, StageManager is found by group — and bare
# `class_name` references resolve inconsistently in headless test runs. Preloading the
# script gets the constants without depending on either.
const _TRAITS: GDScript = preload("res://scripts/player/trait_manager.gd")
const _STAGES: GDScript = preload("res://scripts/systems/stage_manager.gd")

# Font sizes are multiples of 8, Kenney Pixel's native size. Asking a pixel font for 9 or
# 11px renders it mushy and unevenly weighted; whole multiples stay crisp.
const SIZE_TITLE: int = 24
const SIZE_BODY: int = 16
const SIZE_QUIET: int = 8

const COLOR_TITLE: Color = Color("e74c3c")
const COLOR_BODY: Color = Color(0.90, 0.90, 0.95)
const COLOR_QUIET: Color = Color(0.62, 0.62, 0.70)

# Era-appropriate tint on the dimmer, so the ending is coloured by how far the player got
# rather than always reading as the same prehistoric red. Keyed on StageManager.Era.
const _ERA_NAMES: Dictionary = {
	1: "The Prehistoric Era",
	2: "The Industrial Era",
	3: "The Cyberpunk Era",
}
const _ERA_DIM: Dictionary = {
	1: Color(0.05, 0.02, 0.02, 0.50),
	2: Color(0.05, 0.04, 0.02, 0.50),
	3: Color(0.03, 0.02, 0.06, 0.50),
}

# The frame is worth a beat before the text lands on it.
const FADE_IN: float = 0.45
const TEXT_DELAY: float = 0.35

@onready var _panel: Control = $Control
@onready var _dimmer: ColorRect = $Control/Dimmer
@onready var _era_line: Label = $Control/EraLine
@onready var _title: Label = $Control/Title
@onready var _readout: VBoxContainer = $Control/Readout
@onready var _stats: Label = $Control/Readout/Stats
@onready var _remains: Label = $Control/Readout/Remains
@onready var _closing: Label = $Control/Readout/Closing
@onready var _menu_btn: Button = $Control/Readout/MenuButton


func _ready() -> void:
	_panel.visible = false
	_style()
	_menu_btn.pressed.connect(_on_menu_pressed)
	EventBus.player_died.connect(_on_player_died)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _style() -> void:
	_era_line.add_theme_font_size_override("font_size", SIZE_QUIET)
	_era_line.add_theme_color_override("font_color", COLOR_QUIET)

	_title.text = "YOU DIED"
	_title.add_theme_font_size_override("font_size", SIZE_TITLE)
	_title.add_theme_color_override("font_color", COLOR_TITLE)
	# The one place a drop shadow is load-bearing: the title sits over whatever backdrop
	# the run reached, and the cyberpunk one is bright enough to swallow red text.
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)

	_stats.add_theme_font_size_override("font_size", SIZE_BODY)
	_stats.add_theme_color_override("font_color", COLOR_BODY)

	# Body size, not quiet size. This is the line that gives the numbers their meaning, and
	# at 8px it was the least legible thing on a screen it should be carrying. It stays
	# subordinate to the stats line by colour instead of by size.
	_remains.add_theme_font_size_override("font_size", SIZE_BODY)
	_remains.add_theme_color_override("font_color", COLOR_QUIET)

	_closing.add_theme_font_size_override("font_size", SIZE_BODY)
	_closing.add_theme_color_override("font_color", COLOR_QUIET)

	_menu_btn.add_theme_font_size_override("font_size", SIZE_QUIET)
	_menu_btn.add_theme_stylebox_override("normal", _btn_style(Color(0.14, 0.13, 0.18, 0.95)))
	_menu_btn.add_theme_stylebox_override("hover", _btn_style(Color(0.22, 0.18, 0.24, 0.98)))
	_menu_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.09, 0.13, 1.0)))
	_menu_btn.add_theme_stylebox_override("focus", _btn_style(Color(0.22, 0.18, 0.24, 0.98)))


func _btn_style(bg: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COLOR_TITLE
	sb.border_width_top = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	return sb


func _on_player_died() -> void:
	if _panel.visible:
		return
	# Read the run's numbers before end_run(). It only flips is_run_active and leaves the
	# stats alone (start_new_run resets them), but depending on that from a distance is how
	# a display bug gets introduced later.
	_fill_in()
	GameState.end_run()
	GameState.push_pause(PAUSE_ID)
	_panel.visible = true
	_play_in()


func _fill_in() -> void:
	var era: int = _current_era()
	_era_line.text = _ERA_NAMES.get(era, _ERA_NAMES[1])
	_dimmer.color = _ERA_DIM.get(era, _ERA_DIM[1])

	# The one line of real numbers. Wave reads 1-based to the player: current_wave counts
	# waves reached, and dying on the first should not report "Wave 0".
	_stats.text = "Wave %d  ·  %d killed  ·  Era %d of 3" % [
		maxi(GameState.current_wave, 1), GameState.kill_count, era,
	]
	_remains.text = _remains_line()


# StageManager is found by group — the same lookup base_enemy.gd and year_shrine.gd use.
# Falls back to era 1 when it is absent, as in isolated test scenes.
func _current_era() -> int:
	var stage: Node = get_tree().get_first_node_in_group("stage_manager")
	if stage == null:
		return _STAGES.Era.PREHISTORIC
	return stage.current_era


# What, if anything, the player still had. This is the line that makes the numbers mean
# something: the run is a slow trade of your body for time, so the ending reports what was
# left of it.
func _remains_line() -> String:
	var tm: Node = _trait_manager()
	if tm == null:
		return ""
	var intact: Array[String] = []
	for trait_name: String in _TRAITS.ALL_TRAITS:
		if tm.is_intact(trait_name):
			intact.append(trait_name)
	if intact.is_empty():
		return "Nothing of you was still intact."
	if intact.size() == _TRAITS.ALL_TRAITS.size():
		return "You were still whole. It got you anyway."
	if intact.size() == 1:
		return "Only your %s was still yours." % intact[0]
	return "%d of 7 traits still yours: %s." % [intact.size(), ", ".join(intact)]


func _trait_manager() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("TraitManager")


# Tweens run on a paused tree because process_mode is ALWAYS on this layer.
func _play_in() -> void:
	_dimmer.modulate.a = 0.0
	_era_line.modulate.a = 0.0
	_title.modulate.a = 0.0
	_readout.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(_dimmer, "modulate:a", 1.0, FADE_IN)
	t.parallel().tween_property(_era_line, "modulate:a", 1.0, FADE_IN)
	t.parallel().tween_property(_title, "modulate:a", 1.0, FADE_IN)
	t.tween_interval(TEXT_DELAY)
	t.tween_property(_readout, "modulate:a", 1.0, FADE_IN)


func _on_menu_pressed() -> void:
	_panel.visible = false
	GameState.pop_pause(PAUSE_ID)
	GameState.return_to_menu()
