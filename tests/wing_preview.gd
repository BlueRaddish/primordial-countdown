# wing_preview.gd
# Screenshots the player with an evolved trait forced on, so art wiring can be checked
# without playing to the trait that unlocks it.
#
# WHY THIS EXISTS. The last art change shipped with the character at roughly twice its
# intended height, and nothing caught it: the smoke tests assert on numbers, and numbers
# were all correct — the sprite scale was being overwritten a layer below them. Wings are
# the same class of change (a texture, a scale, an anchor), so they get the same class of
# check: look at the actual rendered frame.
#
# Must run WITHOUT --headless. Headless has no rendering server, so the viewport texture
# comes back blank and the capture is worthless.
#
#   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 640x360 \
#       tests/wing_preview.tscn
#
# Writes user://wing_preview_*.png and prints the resolved paths before quitting.
extends Node2D

# Frames to let the game settle before capturing. The player falls to the floor and the
# camera smooths toward it; capturing sooner catches the character mid-air at an offset
# that is real but not representative.
const SETTLE_FRAMES: int = 45
# Frames between captures, chosen so the wing beat lands on different poses rather than
# three shots of the same one.
const GAP_FRAMES: int = 7
const SHOTS: int = 4

var _frame: int = 0
var _taken: int = 0
var _player: Node2D


func _ready() -> void:
	var game: PackedScene = load("res://scenes/main/game.tscn")
	add_child(game.instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == SETTLE_FRAMES:
		_force_wings()
	if _frame < SETTLE_FRAMES + 4 or _taken >= SHOTS:
		if _taken >= SHOTS:
			get_tree().quit()
		return
	if (_frame - SETTLE_FRAMES) % GAP_FRAMES != 0:
		return
	_capture()


func _force_wings() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		push_error("[wing_preview] no player in the scene")
		get_tree().quit(1)
		return
	var marks: Node = _player.get_node_or_null("BodyMarks")
	if marks == null:
		push_error("[wing_preview] player has no BodyMarks child")
		get_tree().quit(1)
		return
	# Straight at BodyMarks rather than through the evolved-trait manager: this is a
	# rendering check, and going through the trait system would drag in unlock rules that
	# have nothing to do with whether the sprite lands in the right place.
	marks.call("set_marks", true, true, false, false, Color.TRANSPARENT)
	print("[wing_preview] wings + tail forced on")


func _capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[wing_preview] no viewport image — are you running with --headless?")
		get_tree().quit(1)
		return
	# Blown up 3x with nearest so the pixels stay square when the shot is viewed; the
	# capture itself is the real 640x360 frame.
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var path: String = "user://wing_preview_%d.png" % _taken
	img.save_png(path)
	print("[wing_preview] wrote %s" % ProjectSettings.globalize_path(path))
	_taken += 1
