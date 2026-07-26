# ui_smoke_test.gd
# Boots the game scene, forces every screen open in turn, checks each panel fits and
# sits inside the viewport, and saves a screenshot of each.
#
# Run (needs a window — screenshots require a renderer):
#   godot --path . --resolution 1280x720 res://tests/ui_smoke_test.tscn
# Exit code is non-zero if any check failed, so it works in a script.
#
# WHY: the UI is built in code across five files against a fixed 640x360 viewport, and
# nothing else catches a panel that is too tall or fails to centre. This test found
# both: a character screen 40px taller than the screen, and a devolution popup that
# resolved to global (-245,-134) because its centre anchor went stale when it resized
# itself. Neither is visible from reading the code.
#
# NOTE: do not run `--headless --editor` against this project while the Godot editor
# is open — it hangs on the import lock. Running a scene like this is safe.
extends Node

const VIEWPORT: Vector2 = Vector2(640.0, 360.0)
const SHOT_DIR: String = "res://tests/_uishots"

var _failures: int = 0


func _ready() -> void:
	# The screens under test pause the tree, so this driver must keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	add_child(load("res://scenes/main/game.tscn").instantiate())
	_run()


func _run() -> void:
	await _wait(30)
	await _shot("01_gameplay")

	EventBus.character_screen_toggled.emit(true)
	await _wait(8)
	await _shot("02_character_normal")
	_expect(not GameState.show_dev_tools, "dev tools should default off")
	EventBus.character_screen_toggled.emit(true)
	await _wait(3)

	GameState.show_dev_tools = true
	EventBus.character_screen_toggled.emit(true)
	await _wait(8)
	await _shot("03_character_devtools")
	EventBus.character_screen_toggled.emit(true)
	await _wait(3)

	# Settings first, while nothing else is on screen — the devolution popup sits on a
	# higher CanvasLayer and would cover it.
	var panel: Node = get_tree().get_first_node_in_group("settings_panel")
	_expect(panel != null, "settings panel registered in group")
	if panel:
		panel.call("open")
	await _wait(8)
	await _shot("04_settings")
	if panel:
		panel.call("close")
	await _wait(3)

	EventBus.devolution_pending.emit(["arms", "legs", "gut"], 0)
	await _wait(8)
	await _shot("05_devolution_3")

	# The dev "reveal all" case: seven options, which must wrap to a second row.
	EventBus.devolution_pending.emit(
		["arms", "legs", "gut", "lungs", "eyes", "head", "skin"], 1
	)
	await _wait(8)
	await _shot("06_devolution_7")
	_check_bounds("devolution 7-option")
	_check_devolution_pacing()

	print("[ui_smoke] FAILURES: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---- Checks ----

func _check_bounds(tag: String) -> void:
	"""Every panel must fit the viewport AND be fully inside it."""
	var seen: int = 0
	for node: Node in _all(get_tree().root):
		if not (node is Panel):
			continue
		var p: Panel = node as Panel
		var g: Vector2 = p.global_position
		var owner_name: String = p.get_parent().name if p.get_parent() else "?"
		seen += 1
		if p.size.x > VIEWPORT.x or p.size.y > VIEWPORT.y:
			_fail("[%s] %s is %s, larger than the %s viewport"
				% [tag, owner_name, str(p.size), str(VIEWPORT)])
		elif g.x < 0.0 or g.y < 0.0 \
				or g.x + p.size.x > VIEWPORT.x or g.y + p.size.y > VIEWPORT.y:
			_fail("[%s] %s at %s size %s runs off-screen"
				% [tag, owner_name, str(g), str(p.size)])
		else:
			print("[ui_smoke] ok %s at %s size %s" % [owner_name, str(g), str(p.size)])
	_expect(seen > 0, "[%s] found at least one panel" % tag)


func _check_devolution_pacing() -> void:
	"""The opening steps must stay cheap — this is the pacing fix, and it is easy to
	undo by accident when retuning starting_years."""
	var devo: Node = get_tree().get_first_node_in_group("devolution_system")
	if not devo:
		_fail("devolution system not found")
		return
	var costs: Array = devo.call("get_step_costs")
	if costs.is_empty():
		_fail("no devolution step costs")
		return
	print("[ui_smoke] first devolution at %.1f years, last %.1f" % [
		costs[0], costs[costs.size() - 1]
	])
	_expect(costs[0] <= 25.0, "first devolution within 25 years (got %.1f)" % costs[0])


# ---- Helpers ----

func _expect(condition: bool, what: String) -> void:
	if condition:
		print("[ui_smoke] ok %s" % what)
	else:
		_fail(what)


func _fail(msg: String) -> void:
	_failures += 1
	printerr("[ui_smoke] FAIL: %s" % msg)


func _wait(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png("%s/%s.png" % [SHOT_DIR, shot_name])
	if err != OK:
		_fail("could not save screenshot %s (err %d)" % [shot_name, err])


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c: Node in n.get_children():
		out.append_array(_all(c))
	return out
