# devo_card_preview.gd
# Screenshots the devolution popup so its look can be judged without playing to a
# devolution step.
#
# WHY: the cards are the moment the run is about, and "they look ugly" is not something
# a smoke test can measure. Both previous art defects in this project — a character at
# twice its height, and wings anchored at the knees — shipped with every assertion
# green, because the numbers were right and the pixels were not.
#
# Must run WITHOUT --headless; headless has no rendering server and the capture is blank.
#
#   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 640x360 \
#       tests/devo_card_preview.tscn
#
# Shoots the popup twice: the 3-option case that normal play shows, and the 7-option
# dev "reveal all" case that wraps to a second row.
extends Node2D

const SETTLE_FRAMES: int = 45
# The popup pauses the tree, so this node runs on PROCESS_MODE_ALWAYS and counts frames
# itself rather than relying on anything that stops when paused.
const HOLD_FRAMES: int = 12

const THREE: Array = ["arms", "eyes", "legs"]
const SEVEN: Array = ["arms", "legs", "gut", "lungs", "eyes", "skin", "head"]

var _frame: int = 0
var _shot: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child((load("res://scenes/main/game.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		SETTLE_FRAMES:
			_open(THREE, 0)
		SETTLE_FRAMES + HOLD_FRAMES:
			_capture("3opt")
		SETTLE_FRAMES + HOLD_FRAMES + 2:
			_degrade_some()
			_open(SEVEN, 4)
		SETTLE_FRAMES + HOLD_FRAMES * 2 + 2:
			_capture("7opt")
			get_tree().quit()


func _degrade_some() -> void:
	"""Push a few traits off Intact so the second shot exercises the states that only
	appear later in a run: the PARTIAL -> LOST transition text and the hotter background
	a full loss gets. A shot of seven identical Intact cards would prove nothing about
	the styling that actually varies."""
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not players[0].has_node("TraitManager"):
		push_warning("[devo_preview] no TraitManager; second shot will be all-Intact")
		return
	var mgr: Node = players[0].get_node("TraitManager")
	for tname: String in ["arms", "eyes", "legs"]:
		mgr.call("devolve_trait", tname)
	# arms twice, so at least one card shows the full-loss styling.
	mgr.call("devolve_trait", "arms")

	# Losing arms grows Wings, and that popup covers the cards this shot exists to show.
	# Hiding it is honest here: it is a real reaction to a real state change, just not
	# the thing under test.
	var evolved: Node = get_tree().get_root().find_child("EvolvedTraitPopup", true, false)
	if evolved != null and evolved is CanvasLayer:
		(evolved as CanvasLayer).visible = false


func _open(options: Array, step: int) -> void:
	EventBus.devolution_pending.emit(options, step)


func _capture(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[devo_preview] no viewport image — running with --headless?")
		get_tree().quit(1)
		return
	# 2x nearest so the pixels stay square when viewed; the capture is the real frame.
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path: String = "user://devo_%s.png" % tag
	img.save_png(path)
	print("[devo_preview] wrote %s" % ProjectSettings.globalize_path(path))
	_shot += 1
