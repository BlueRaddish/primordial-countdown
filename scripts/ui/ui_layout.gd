# ui_layout.gd
# Shared layout helpers for the code-built UI.
#
# WHY THIS EXISTS: `set_anchors_preset(PRESET_CENTER)` followed by assigning `size`
# and `position` only centres a Control if the size is assigned in the same pass. A
# panel that is resized later — the devolution popup, which sizes itself to the
# number of options — keeps the offsets the preset computed at build time and ends up
# placed at raw negative coordinates, hanging off the top-left corner of the screen.
#
# Setting all four anchors and all four offsets explicitly has no such ordering
# dependency: it is unambiguous whenever it runs.
#
# Deliberately NOT a `class_name`: consumers preload it instead. A global class is
# only visible once the editor has re-scanned, which makes a fresh helper invisible
# to a headless run against an existing import cache.
extends RefCounted

# The game renders at a fixed 640x360 (project.godot window/size/viewport_*). Any
# centred panel has to fit inside this or it hangs off the edges.
const VIEWPORT: Vector2 = Vector2(640.0, 360.0)


static func center(panel: Control, w: float, h: float) -> void:
	"""Centre `panel` in its parent at exactly w x h, safe to call at any time."""
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_right = w * 0.5
	panel.offset_bottom = h * 0.5


static func fits(w: float, h: float) -> bool:
	return w <= VIEWPORT.x and h <= VIEWPORT.y
