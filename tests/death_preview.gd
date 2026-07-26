# death_preview.gd
# Screenshots the ending screen with a plausible run's state forced on, so it can be
# judged as a picture without playing to a real death.
#
# WHY THIS EXISTS. The ending screen is almost entirely a visual claim: that the frozen
# player and the era backdrop read through a thin dimmer, and that Kenney Pixel stays
# crisp at the sizes chosen. The smoke tests assert on numbers and would pass just as
# happily with unreadable text over a black rectangle. So this looks at the frame.
#
# Must run WITHOUT --headless. Headless has no rendering server and the capture comes back
# blank.
#
#   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 640x360 \
#       tests/death_preview.tscn
#
# Writes user://death_preview_*.png and prints the resolved paths before quitting.
extends Node2D

# Long enough for the player to land and the camera to settle; capturing sooner freezes
# the sprite mid-fall, which is real but not representative.
const SETTLE_FRAMES: int = 45
# The screen fades in over ~0.8s total, so the shots are spread past that to catch the
# mid-fade beat and the settled final frame.
const SHOT_FRAMES: Array[int] = [12, 30, 75]

# A run that got somewhere: mid-game wave, a believable kill count, and five of seven
# traits degraded, which exercises the "N of 7 still yours" branch rather than either
# extreme.
#
# Set through the `traits` dictionary directly rather than via set_trait_stage(), because
# every route through the trait system opens UI on top of the screen being photographed:
# `trait_extinct` at LOST unlocks Claws (evolved-trait popup + loadout editor), and even
# PARTIAL unlocks Backstep Slash, whose requirement is literally "Arms Partial". Both
# earlier attempts shot the loadout editor instead of the ending. Writing the dictionary
# emits nothing; recalculate_all() then rebuilds the player's stats and sprite from it and
# emits nothing either, so the frozen sprite is still correctly degraded.
const FORCED_WAVE: int = 6
const FORCED_KILLS: int = 41
const FORCED_PARTIAL: Array[String] = ["arms", "gut", "lungs", "eyes", "skin"]

# Hard ceiling so a missed quit condition fails loudly instead of hanging a test run.
const GIVE_UP_FRAMES: int = 300

var _frame: int = 0
var _taken: int = 0
var _fired: bool = false


func _ready() -> void:
	# Required, not incidental: the death screen calls GameState.push_pause(), which pauses
	# the whole tree. Without ALWAYS this node stops processing the moment it forces the
	# death and never reaches its own quit — the run hangs with no output.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The game goes under the tree root, NOT under this node. Process mode is inherited, so
	# parenting it here would hand the whole game PROCESS_MODE_ALWAYS and it would keep
	# simulating straight through the pause — which is not a cosmetic difference: death
	# disables the player's collision, so an unpaused player falls through the floor and
	# drags the camera off the arena. The first version of this harness photographed empty
	# space for exactly that reason. Under root it inherits normal pause behaviour and
	# genuinely freezes, which is what the ending screen is meant to be showing.
	get_tree().root.add_child.call_deferred(load("res://scenes/main/game.tscn").instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == SETTLE_FRAMES:
		_force_death()
		return
	if _frame > GIVE_UP_FRAMES:
		push_error("[death_preview] gave up after %d frames with %d/%d shots" % [
			GIVE_UP_FRAMES, _taken, SHOT_FRAMES.size(),
		])
		get_tree().quit(1)
		return
	if not _fired:
		return
	var since: int = _frame - SETTLE_FRAMES
	if _taken < SHOT_FRAMES.size() and since >= SHOT_FRAMES[_taken]:
		_capture()
	elif _taken >= SHOT_FRAMES.size():
		get_tree().quit()


func _force_death() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("[death_preview] no player in the scene")
		get_tree().quit(1)
		return
	var tm: Node = player.get_node_or_null("TraitManager")
	if tm == null:
		push_error("[death_preview] player has no TraitManager child")
		get_tree().quit(1)
		return

	for trait_name: String in FORCED_PARTIAL:
		tm.traits[trait_name] = 1  # TraitManager.STAGE_PARTIAL
	tm.recalculate_all()
	GameState.current_wave = FORCED_WAVE
	GameState.kill_count = FORCED_KILLS

	EventBus.player_died.emit()
	_fired = true
	print("[death_preview] death forced at wave %d, %d kills, %d traits degraded" % [
		FORCED_WAVE, FORCED_KILLS, FORCED_PARTIAL.size(),
	])


func _capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[death_preview] no viewport image — are you running with --headless?")
		get_tree().quit(1)
		return
	# Blown up 3x with nearest so pixels stay square when the shot is viewed; the capture
	# itself is the real 640x360 frame.
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var path: String = "user://death_preview_%d.png" % _taken
	img.save_png(path)
	# Reported every shot because "is the world in frame at all" is the whole point of this
	# check, and an empty frame looks identical to a correctly-dimmed one at a glance.
	print("[death_preview] wrote %s | camera %s | player %s visible=%s" % [
		ProjectSettings.globalize_path(path), _camera_pos(), _player_pos(), _player_visible(),
	])
	_taken += 1


func _camera_pos() -> String:
	var cam: Camera2D = get_viewport().get_camera_2d()
	return "none" if cam == null else str(cam.global_position.round())


func _player_pos() -> String:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	return "none" if p == null else str(p.global_position.round())


func _player_visible() -> String:
	var p: CanvasItem = get_tree().get_first_node_in_group("player") as CanvasItem
	return "none" if p == null else str(p.is_visible_in_tree())
