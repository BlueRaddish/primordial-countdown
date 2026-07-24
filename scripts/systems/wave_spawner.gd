# wave_spawner.gd
# Wave-based enemy spawning system.
# Next wave starts only after all enemies from the current wave are dead.
extends Node2D

@export var enemy_scene: PackedScene
@export var base_enemies_per_wave: int = 5
@export var enemies_per_wave_growth: int = 2
@export var spawn_stagger_delay: float = 0.15
@export var wave_delay: float = 2.0 # Delay between wave clear and next wave start

# Spawn area bounds (relative to this node's position).
@export var spawn_min_x: float = -200.0
@export var spawn_max_x: float = 200.0
@export var spawn_y: float = 0.0 # Y position for spawned enemies

var _current_wave: int = 0
var _alive_enemies: Array[Node] = []
var _spawning: bool = false
var _wave_delay_timer: float = 0.0
var _spawn_queue: int = 0
var _spawn_timer: float = 0.0
var _started: bool = false


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	# Start first wave after a brief delay.
	_wave_delay_timer = 1.5
	_started = true


func _process(delta: float) -> void:
	if not _started:
		return

	# Wave delay countdown.
	if _wave_delay_timer > 0.0:
		_wave_delay_timer -= delta
		if _wave_delay_timer <= 0.0:
			_start_next_wave()
		return

	# Staggered spawning.
	if _spawning and _spawn_queue > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_one_enemy()
			_spawn_queue -= 1
			_spawn_timer = spawn_stagger_delay
			if _spawn_queue <= 0:
				_spawning = false


func _start_next_wave() -> void:
	_current_wave += 1
	GameState.current_wave = _current_wave
	var count: int = base_enemies_per_wave + (_current_wave - 1) * enemies_per_wave_growth
	_spawn_queue = count
	_spawning = true
	_spawn_timer = 0.0
	EventBus.wave_started.emit(_current_wave, count)


func _spawn_one_enemy() -> void:
	if not enemy_scene:
		return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	var spawn_x: float = global_position.x + randf_range(spawn_min_x, spawn_max_x)
	enemy.global_position = Vector2(spawn_x, global_position.y + spawn_y)
	get_parent().add_child(enemy)
	_alive_enemies.append(enemy)


func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies.erase(enemy)

	# Clean up any freed references.
	var cleaned: Array[Node] = []
	for e: Node in _alive_enemies:
		if is_instance_valid(e):
			cleaned.append(e)
	_alive_enemies = cleaned

	# Check for wave clear.
	if _alive_enemies.is_empty() and not _spawning and _current_wave > 0:
		EventBus.wave_cleared.emit(_current_wave)
		_wave_delay_timer = wave_delay
