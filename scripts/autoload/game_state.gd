# game_state.gd — Autoload
# Current stage, run stats, active traits, world evolution level.
extends Node

# ---- Player health ----
var player_max_health: float = 100.0
var player_health: float = 100.0
var is_run_active: bool = false

# ---- Kill tracking / devolution bar ----
var kill_count: int = 0
var devolution_points: float = 0.0
var devolution_threshold: float = 5.0 # Points needed for next devolution milestone
var total_devolutions: int = 0

# ---- Wave tracking ----
var current_wave: int = 0

# ---- Scene paths ----
const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"
const GAME_PATH: String = "res://scenes/main/game.tscn"


func _ready() -> void:
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	EventBus.enemy_died.connect(_on_enemy_died)


# ---- Run lifecycle ----

func start_new_run() -> void:
	player_health = player_max_health
	kill_count = 0
	devolution_points = 0.0
	total_devolutions = 0
	current_wave = 0
	is_run_active = true
	EventBus.player_health_changed.emit(player_health, player_max_health)
	get_tree().change_scene_to_file(GAME_PATH)


func end_run() -> void:
	is_run_active = false


func return_to_menu() -> void:
	end_run()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


# ---- Health helpers ----

func damage_player(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_run_active:
		return
	player_health = maxf(player_health - amount, 0.0)
	EventBus.player_health_changed.emit(player_health, player_max_health)
	EventBus.player_hit.emit(amount, knockback_dir)
	if player_health <= 0.0:
		EventBus.player_died.emit()


func heal_player(amount: float) -> void:
	player_health = minf(player_health + amount, player_max_health)
	EventBus.player_health_changed.emit(player_health, player_max_health)


# ---- Kill / Devolution tracking ----

func _on_enemy_died(_enemy: Node) -> void:
	register_kill()


func register_kill() -> void:
	kill_count += 1
	devolution_points += 1.0

	if devolution_points >= devolution_threshold:
		devolution_points -= devolution_threshold
		total_devolutions += 1
		EventBus.devolution_milestone_reached.emit(kill_count)


func get_devolution_progress() -> float:
	"""Returns 0.0 to 1.0 progress toward next devolution."""
	if devolution_threshold <= 0.0:
		return 0.0
	return clampf(devolution_points / devolution_threshold, 0.0, 1.0)


# ---- Scene transitions ----

func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
