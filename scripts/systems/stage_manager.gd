# stage_manager.gd
# Owns the run's three-era progression: prehistoric -> industrial/steampunk -> cyberpunk,
# one continuous arena reskinned in place. Reskin + trigger only — wave counts, enemy
# stats, health, years, traits and skills are untouched (see wave_spawner.gd, which keeps
# running its own boss-every-3rd-wave cadence with no awareness this exists).
#
# Era order/boundaries are hardcoded rather than driven by wave number: era 1 ends when
# boss 1 dies (wave 3), era 2 when boss 2 dies (wave 6), matching wave_spawner.gd's
# existing `boss_every_n_waves = 3`. The visual swap itself is gated behind the player
# physically walking through an EraDoor, not the wave counter directly — see
# `_on_boss_defeated()`.
class_name StageManager
extends Node

enum Era { PREHISTORIC = 1, INDUSTRIAL = 2, CYBERPUNK = 3 }

# A distinct steely tint for the industrial Hopper, which reuses GraveRobber's own sprite
# (already the Lunger) sourced from a different sheet — see build_industrial_sprites.py's
# docstring. Without this the two would only differ by pose, not colour.
const INDUSTRIAL_HOPPER_TINT: Color = Color(0.75, 0.85, 1.25)

var current_era: int = Era.PREHISTORIC
var _bosses_defeated: int = 0

# --- Enemy appearance, per era per behavior. Y offsets follow the same formula
# base_enemy.gd's own BEHAVIOR_SPRITE_Y already uses: -(crop_height * scale) / 2, so a
# bottom-anchored frame's feet land on the collider's base after scaling. Scale stays
# 0.6 for every minion in every era (BEHAVIOR_ATTACK_PROFILES / hitboxes are untouched,
# so footprint parity with the existing cyberpunk set keeps hits feeling consistent).
const _ENEMY_APPEARANCE: Dictionary = {
	Era.PREHISTORIC: {
		BaseEnemy.Behavior.WALKER: {
			"frames": preload("res://resources/sprite_frames/enemy_walker_prehistoric.tres"),
			"y": -8.1, "scale": Vector2(0.6, 0.6),
		},
		BaseEnemy.Behavior.LUNGER: {
			"frames": preload("res://resources/sprite_frames/enemy_lunger_prehistoric.tres"),
			"y": -8.1, "scale": Vector2(0.6, 0.6),
		},
		BaseEnemy.Behavior.HOPPER: {
			"frames": preload("res://resources/sprite_frames/enemy_hopper_prehistoric.tres"),
			"y": -8.7, "scale": Vector2(0.6, 0.6),
		},
	},
	Era.INDUSTRIAL: {
		BaseEnemy.Behavior.WALKER: {
			"frames": preload("res://resources/sprite_frames/enemy_walker_industrial.tres"),
			"y": -10.2, "scale": Vector2(0.6, 0.6),
		},
		BaseEnemy.Behavior.LUNGER: {
			"frames": preload("res://resources/sprite_frames/enemy_lunger_industrial.tres"),
			"y": -10.5, "scale": Vector2(0.6, 0.6),
		},
		BaseEnemy.Behavior.HOPPER: {
			"frames": preload("res://resources/sprite_frames/enemy_hopper_industrial.tres"),
			"y": -12.6, "scale": Vector2(0.6, 0.6),
			"modulate": INDUSTRIAL_HOPPER_TINT,
		},
	},
	# Era.CYBERPUNK has no entry: get_enemy_appearance() returns {} for it, which sends
	# base_enemy.gd back to its own BEHAVIOR_SPRITE_FRAMES/_Y/_SCALE consts — the exact
	# Biker/Punk/Cyborg set already shipped, unchanged.
}

# --- Boss appearance, per era. Unlike minions, era 3 needs an explicit entry too: the
# boss was never reskinned for cyberpunk (still the original 0x72 "big demon" in
# boss_enemy.tscn's own scene-authored default) — boss_cyberpunk.tres fixes that by
# reusing the existing walker Biker frames at boss scale, since pack 18 has no
# boss-sized 4th character.
const _BOSS_APPEARANCE: Dictionary = {
	Era.PREHISTORIC: {
		"frames": preload("res://resources/sprite_frames/boss_prehistoric.tres"),
		"y": -27.5, "scale": Vector2(1.0, 1.0),
	},
	Era.INDUSTRIAL: {
		"frames": preload("res://resources/sprite_frames/boss_industrial.tres"),
		"y": -34.2, "scale": Vector2(1.8, 1.8),
	},
	Era.CYBERPUNK: {
		"frames": preload("res://resources/sprite_frames/boss_cyberpunk.tres"),
		"y": -30.6, "scale": Vector2(1.8, 1.8),
	},
}

# --- Backdrops, per era. Era 1 is authored directly on game.tscn's ParallaxBackdrop node
# (the run's starting state), so it has no entry here — only the two transitions need
# runtime data.
const _BACKDROPS: Dictionary = {
	Era.INDUSTRIAL: {
		"textures": [
			preload("res://assets/sprites/backgrounds/town/town_back.png"),
			preload("res://assets/sprites/backgrounds/town/town_middle.png"),
		] as Array[Texture2D],
		"offsets": [0.0, 0.0] as Array[float],
		"scroll": [0.08, 0.25] as Array[float],
		"canvas_height": 288.0,
		"horizon_y": 288.0,
	},
	Era.CYBERPUNK: {
		"textures": [
			preload("res://assets/sprites/backgrounds/cyberpunk/cyberpunk_back.png"),
			preload("res://assets/sprites/backgrounds/cyberpunk/cyberpunk_middle.png"),
			preload("res://assets/sprites/backgrounds/cyberpunk/cyberpunk_foreground.png"),
		] as Array[Texture2D],
		"offsets": [0.0, 0.0, 0.0] as Array[float],
		"scroll": [0.06, 0.18, 0.32] as Array[float],
		"canvas_height": 272.0,
		"horizon_y": 288.0,
	},
}


func _ready() -> void:
	add_to_group("stage_manager")
	EventBus.boss_defeated.connect(_on_boss_defeated)
	# game.tscn's ParallaxBackdrop is already authored with era 1's (swamp) textures as
	# its scene default, so no backdrop swap is needed for the run's starting era.


func _on_boss_defeated() -> void:
	_bosses_defeated += 1
	match _bosses_defeated:
		1:
			_spawn_door(Era.INDUSTRIAL)
		2:
			_spawn_door(Era.CYBERPUNK)
		_:
			pass # TODO: post-era-3 state (ending/victory) is undecided — no further eras.


# ---- Appearance queries, pulled by newly-spawned enemies/bosses (see base_enemy.gd's
# _apply_behavior_sprite() and boss_enemy.gd's _apply_era_sprite()). Nothing here pushes
# to already-alive enemies — they keep whatever they spawned with.

func get_enemy_appearance(behavior: BaseEnemy.Behavior) -> Dictionary:
	var era_table: Dictionary = _ENEMY_APPEARANCE.get(current_era, {})
	return era_table.get(behavior, {})


func get_boss_appearance() -> Dictionary:
	return _BOSS_APPEARANCE.get(current_era, {})


# ---- Era transitions ----

func advance_to_era(era: int) -> void:
	current_era = era
	var backdrop_data: Dictionary = _BACKDROPS.get(era, {})
	if backdrop_data.is_empty():
		return
	var backdrop: Node = get_tree().get_first_node_in_group("parallax_backdrop")
	if backdrop and backdrop.has_method("set_layers"):
		backdrop.call(
			"set_layers",
			backdrop_data["textures"], backdrop_data["offsets"], backdrop_data["scroll"],
			backdrop_data["canvas_height"], backdrop_data["horizon_y"]
		)


func _spawn_door(target_era: int) -> void:
	var door: EraDoor = EraDoor.new()
	door.target_era = target_era
	door.global_position = _pick_door_position()
	get_parent().add_child(door)


func _pick_door_position() -> Vector2:
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if arena:
		var ground_points: PackedVector2Array = arena.call("get_ground_spawn_points", 1)
		if ground_points.size() > 0:
			return ground_points[0]
	# Fallback: the arena's horizontal midpoint, ground level — same numbers
	# wave_spawner.gd's WaveSpawner node sits at in game.tscn.
	return Vector2(540.0, 288.0)
