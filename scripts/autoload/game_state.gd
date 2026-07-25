# game_state.gd — Autoload
# Current stage, run stats, world evolution level.
#
# Note: this deliberately does NOT own the devolution bar. PLANNING1 section 8
# keeps devolution in devolution_system.gd so the two progression systems stay
# separable. GameState only tracks health, run lifecycle, and raw run stats.
extends Node

# ---- Player health ----
var player_max_health: float = 100.0
var player_health: float = 100.0
var is_run_active: bool = false

# ---- Run stats (display only — no system reads these to make decisions) ----
var kill_count: int = 0
var current_wave: int = 0

# ---- Dev / testing ----
var god_mode: bool = false
var no_skill_cooldown: bool = false
# Holds the year countdown still, so a skill can be playtested for as long as
# needed without the run devolving out from under it.
var freeze_years: bool = false

# Devolution normally offers a randomized choice of 3 traits to degrade. This dev
# toggle instead reveals EVERY still-degradable trait as an option, so a tester can
# steer straight to a specific trait or evolved-trait combo.
var devolution_player_choice: bool = false

# ---- Pause ownership ----
# Several screens can pause the game at once (a devolution step can fire while the
# character screen is open). Refcount it so closing one never unpauses the others.
var _pause_holders: Array[String] = []

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
	current_wave = 0
	is_run_active = true
	_pause_holders.clear()
	get_tree().paused = false
	EventBus.player_health_changed.emit(player_health, player_max_health)
	get_tree().change_scene_to_file(GAME_PATH)


func end_run() -> void:
	is_run_active = false


func return_to_menu() -> void:
	end_run()
	_pause_holders.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


# ---- Pause refcounting ----

func push_pause(holder_id: String) -> void:
	if not _pause_holders.has(holder_id):
		_pause_holders.append(holder_id)
	get_tree().paused = true


func pop_pause(holder_id: String) -> void:
	_pause_holders.erase(holder_id)
	get_tree().paused = not _pause_holders.is_empty()


func is_paused_by(holder_id: String) -> bool:
	return _pause_holders.has(holder_id)


# ---- Health helpers ----

func damage_player(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_run_active:
		return
	if god_mode:
		# Still report the hit so knockback and hit feedback stay testable.
		EventBus.player_hit.emit(0.0, knockback_dir)
		return
	player_health = maxf(player_health - amount, 0.0)
	EventBus.player_health_changed.emit(player_health, player_max_health)
	EventBus.player_hit.emit(amount, knockback_dir)
	if player_health <= 0.0:
		EventBus.player_died.emit()


func heal_player(amount: float) -> void:
	if amount <= 0.0:
		return
	player_health = minf(player_health + amount, player_max_health)
	EventBus.player_health_changed.emit(player_health, player_max_health)


# ---- Dev toggles ----

func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	EventBus.test_modes_changed.emit()


func toggle_god_mode() -> void:
	set_god_mode(not god_mode)


func set_no_skill_cooldown(enabled: bool) -> void:
	no_skill_cooldown = enabled
	EventBus.test_modes_changed.emit()


func set_freeze_years(enabled: bool) -> void:
	freeze_years = enabled
	EventBus.test_modes_changed.emit()


# ---- Kill tracking (display only) ----

func _on_enemy_died(_enemy: Node) -> void:
	kill_count += 1


# ---- Scene transitions ----

func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
