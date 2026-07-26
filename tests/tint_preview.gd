# tint_preview.gd
# Screenshots the player at four devolution levels and prints the sprite's actual
# modulate at each, so the "devolution is invisible" report can be settled as either a
# broken system or a badly shaped curve before anything is edited.
#
# The numbers matter as much as the frames here: the complaint is about mid-run
# readability, and "is 3-of-14 visible" is a question about the size of a colour step,
# which the printed modulate answers exactly and a screenshot only suggests.
#
# Must run WITHOUT --headless — same reason as wing_preview.gd, no rendering server
# means a blank capture.
#
#   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 640x360 \
#       tests/tint_preview.tscn
#
# Writes user://tint_preview_*.png and prints the resolved paths before quitting.
extends Node2D

# Let the player land and the camera settle before the first capture, and give the
# invincibility flicker time to finish — it owns modulate.a, and catching it mid-blink
# makes the printed colour look wrong for a reason that has nothing to do with decay.
const SETTLE_FRAMES: int = 60
# Frames between levels. recalculate_all() is synchronous, so this is not waiting on
# state to propagate — it is waiting for the landing dust that losing the legs kicks up,
# which otherwise sits directly over the character in the final capture.
const GAP_FRAMES: int = 20

# Trait stages per level, chosen to hit specific totals out of 14.
# 3/14 is the case the bug report described as invisible.
const LEVELS: Array[Dictionary] = [
	{"name": "0 of 14 (intact)", "stages": {}},
	{"name": "3 of 14 (early run)", "stages": {"arms": 2, "legs": 1}},
	{"name": "7 of 14 (half gone)", "stages": {"arms": 2, "legs": 2, "gut": 2, "lungs": 1}},
	{
		"name": "14 of 14 (total loss)",
		"stages":
		{"arms": 2, "legs": 2, "gut": 2, "lungs": 2, "eyes": 2, "head": 2, "skin": 2}
	},
]

var _frame: int = 0
var _level: int = 0
var _player: Node2D
var _traits: Node


func _ready() -> void:
	# Driving a trait to Lost grants a skill, and the skill-unlock popup pushes a pause
	# holder. Without this the preview's own _process stops with everything else and the
	# run hangs after the first full loss.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game: PackedScene = load("res://scenes/main/game.tscn")
	add_child(game.instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	if _frame == SETTLE_FRAMES and not _resolve_player():
		return
	if (_frame - SETTLE_FRAMES) % GAP_FRAMES != 0:
		return
	if _level >= LEVELS.size():
		get_tree().quit()
		return
	_apply_level(LEVELS[_level])
	_capture(_level)
	_level += 1


func _resolve_player() -> bool:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		push_error("[tint_preview] no player in the scene")
		get_tree().quit(1)
		return false
	_traits = _player.get_node_or_null("TraitManager")
	if _traits == null:
		push_error("[tint_preview] player has no TraitManager child")
		get_tree().quit(1)
		return false
	return true


func _apply_level(level: Dictionary) -> void:
	_traits.call("reset_all")
	var stages: Dictionary = level["stages"]
	for trait_name: String in stages:
		_traits.call("set_trait_stage", trait_name, stages[trait_name])
	_dismiss_popups()


func _dismiss_popups() -> void:
	"""Clear the popups the forced trait losses just raised, so the capture shows the
	player and not an unlock card.

	Sets tree.paused directly rather than calling GameState.pop_pause: the popups are
	being freed, not closed, so nothing will ever pop the holders they pushed."""
	_free_popups_under(get_tree().root)
	get_tree().paused = false


func _free_popups_under(node: Node) -> void:
	for child: Node in node.get_children():
		var script: Script = child.get_script() as Script
		if script and script.resource_path.contains("popup"):
			child.queue_free()
			continue
		_free_popups_under(child)


func _capture(index: int) -> void:
	var sprite: CanvasItem = _player.get_node_or_null("AnimatedSprite2D")
	var mat: ShaderMaterial = sprite.material as ShaderMaterial if sprite else null
	var decay: Variant = mat.get_shader_parameter("decay") if mat else null
	print(
		(
			"[tint_preview] %s -> shader decay %s"
			% [LEVELS[index]["name"], "%.3f" % (decay as float) if decay != null else "n/a"]
		)
	)

	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[tint_preview] no viewport image — are you running with --headless?")
		get_tree().quit(1)
		return
	_save(_zoom_on_player(img), "user://tint_preview_%d_crop.png" % index)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_save(img, "user://tint_preview_%d.png" % index)


func _zoom_on_player(frame: Image) -> Image:
	"""A tight blow-up of just the character.

	The full frame is mostly backdrop, and a 40%-desaturated 20-pixel sprite is not
	something anyone can judge at that size — which is roughly how this got shipped as
	"working" in the first place."""
	var centre: Vector2 = _player.get_global_transform_with_canvas().origin
	var box: int = 72
	var rect: Rect2i = Rect2i(
		clampi(int(centre.x) - box / 2, 0, maxi(0, frame.get_width() - box)),
		clampi(int(centre.y) - box / 2, 0, maxi(0, frame.get_height() - box)),
		mini(box, frame.get_width()),
		mini(box, frame.get_height())
	)
	var crop: Image = frame.get_region(rect)
	crop.resize(crop.get_width() * 6, crop.get_height() * 6, Image.INTERPOLATE_NEAREST)
	return crop


func _save(img: Image, path: String) -> void:
	img.save_png(path)
	print("[tint_preview] wrote %s" % ProjectSettings.globalize_path(path))
