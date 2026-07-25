# window_manager.gd — Autoload
# Owns window presentation: the fullscreen toggle, and nothing else.
#
# The game renders at a fixed 640x360 viewport and the project's stretch settings
# ("canvas_items" + "expand") scale that up to fill whatever window or screen it
# lands in. This node just flips between a resizable window and borderless
# fullscreen; the stretch does the actual scaling.
extends Node


func _ready() -> void:
	# Process even while the tree is paused so fullscreen still toggles on the
	# death screen, character screen, or any devolution popup.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	# F11 (mapped action) or Alt+Enter — the two conventions players reach for.
	var alt_enter: bool = (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event as InputEventKey).keycode == KEY_ENTER
		and (event as InputEventKey).alt_pressed
	)
	if event.is_action_pressed("toggle_fullscreen") or alt_enter:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())


func is_fullscreen() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func set_fullscreen(enabled: bool) -> void:
	if enabled:
		# Borderless fullscreen: fills the monitor without an exclusive mode switch,
		# so alt-tabbing stays instant.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
