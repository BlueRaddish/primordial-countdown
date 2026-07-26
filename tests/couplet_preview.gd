# couplet_preview.gd
# Screenshots the era-transition couplet across its fade so the text can be checked for
# legibility and placement without playing to a boss kill.
#
# The couplet is drawn over whatever backdrop the next era brings and is parented to a
# node that outlives the door that spawned it — both are things only a rendered frame
# will confirm. A smoke test would see the door fire and the era advance and call it
# green whether or not a single pixel of text ever appeared.
#
# Must run WITHOUT --headless — no rendering server means a blank capture.
#
#   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 640x360 \
#       tests/couplet_preview.tscn
#
# Writes user://couplet_preview_*.png and prints the resolved paths before quitting.
extends Node2D

const EraDoorScript := preload("res://scripts/systems/era_door.gd")
const StageManagerScript := preload("res://scripts/systems/stage_manager.gd")

# Let the player land before the door fires, so the capture is not of a character
# falling past the text.
const SETTLE_FRAMES: int = 60
# Frames after the trigger to capture at, chosen to land in the fade-in, the hold, and
# the fade-out rather than three shots of the same held frame.
const SHOT_FRAMES: Array[int] = [20, 60, 130, 175]

var _frame: int = 0
var _fired_at: int = -1
var _taken: int = 0
var _player: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game: PackedScene = load("res://scenes/main/game.tscn")
	add_child(game.instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == SETTLE_FRAMES:
		_fire_door()
		return
	if _fired_at < 0 or _taken >= SHOT_FRAMES.size():
		if _taken >= SHOT_FRAMES.size():
			get_tree().quit()
		return
	if _frame - _fired_at >= SHOT_FRAMES[_taken]:
		_capture()


func _fire_door() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		push_error("[couplet_preview] no player in the scene")
		get_tree().quit(1)
		return

	# Built and triggered directly rather than by killing a boss: this is a check on what
	# the door draws, and routing through a real boss fight would make the capture depend
	# on wave pacing that has nothing to do with the text.
	var door: Node2D = EraDoorScript.new()
	door.set("target_era", StageManagerScript.Era.INDUSTRIAL)
	_player.get_parent().add_child(door)
	door.global_position = _player.global_position
	door.call("_on_body_entered", _player)
	_fired_at = _frame
	print("[couplet_preview] door fired toward the industrial era")


func _capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[couplet_preview] no viewport image — are you running with --headless?")
		get_tree().quit(1)
		return
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path: String = "user://couplet_preview_%d.png" % _taken
	img.save_png(path)
	print(
		(
			"[couplet_preview] +%d frames -> %s"
			% [SHOT_FRAMES[_taken], ProjectSettings.globalize_path(path)]
		)
	)
	_taken += 1
