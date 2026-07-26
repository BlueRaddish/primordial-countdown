# cyberpunk_preview.gd
# Screenshots the live game scene after the first wave has spawned, so the cyberpunk
# enemy reskin and tiled backdrop can be checked by eye rather than by number — same
# reasoning as wing_preview.gd: numbers can all be correct while the rendered frame is
# still wrong (see that script's header for the precedent).
#
# Must run WITHOUT --headless (no rendering server headless, capture comes back blank):
#
#   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1280x720 \
#       tests/cyberpunk_preview.tscn
#
# Writes user://cyberpunk_preview_*.png and prints the resolved paths before quitting.
extends Node2D

const SETTLE_FRAMES: int = 200 # wave-start delay (1.5s) + stagger, comfortably past it
const SHOTS: int = 3
const GAP_FRAMES: int = 20

var _frame: int = 0
var _taken: int = 0


func _ready() -> void:
	var game: PackedScene = load("res://scenes/main/game.tscn")
	add_child(game.instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < SETTLE_FRAMES or _taken >= SHOTS:
		if _taken >= SHOTS:
			get_tree().quit()
		return
	if (_frame - SETTLE_FRAMES) % GAP_FRAMES != 0:
		return
	_capture()


func _capture() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	print("[cyberpunk_preview] enemies alive: %d" % enemies.size())
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[cyberpunk_preview] no viewport image — are you running with --headless?")
		get_tree().quit(1)
		return
	var path: String = "user://cyberpunk_preview_%d.png" % _taken
	img.save_png(path)
	print("[cyberpunk_preview] wrote %s" % ProjectSettings.globalize_path(path))
	_taken += 1
