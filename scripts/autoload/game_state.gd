# game_state.gd — Autoload
# Current stage, run stats, active traits, world evolution level.
extends Node

# ---- Player health ----
var player_max_health: float = 100.0
var player_health: float = 100.0
var is_run_active: bool = false

# ---- Scene paths ----
const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"
const GAME_PATH: String = "res://scenes/main/game.tscn"


func _ready() -> void:
	EventBus.scene_change_requested.connect(_on_scene_change_requested)


# ---- Run lifecycle ----

func start_new_run() -> void:
	player_health = player_max_health
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


# ---- Scene transitions ----

func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
