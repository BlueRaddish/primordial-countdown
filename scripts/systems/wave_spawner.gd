# wave_spawner.gd
# Wave-based enemy spawning system.
# Next wave starts only after all enemies from the current wave are dead.
#
# PLANNING1 section 7 leaves the spawn model undecided between waves and
# continuous. This is the wave implementation; keep the shape configurable so the
# continuous model can be tested against it in the same milestone.
extends Node2D

@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene
@export var base_enemies_per_wave: int = 5
@export var enemies_per_wave_growth: int = 2
@export var max_enemies_per_wave: int = 14
@export var spawn_stagger_delay: float = 0.15
@export var wave_delay: float = 2.0 # Delay between wave clear and next wave start

# PLANNING1 section 7: one boss per stage. Every Nth wave is the boss wave.
@export var boss_every_n_waves: int = 3

# Fraction of each wave that spawns on platforms rather than the ground.
@export var platform_spawn_ratio: float = 0.4

# Fallback spawn bounds, used only if no arena node is found.
@export var spawn_min_x: float = -200.0
@export var spawn_max_x: float = 200.0
@export var spawn_y: float = 0.0

var _current_wave: int = 0
var _alive_enemies: Array[Node] = []
var _spawning: bool = false
var _wave_delay_timer: float = 0.0
var _spawn_queue: int = 0
var _spawn_timer: float = 0.0
var _boss_queued: bool = false
var _started: bool = false
# Set by a PASSAGE shrine: the next wave is counted but never fought.
var _skip_next_wave: bool = false

var _arena: Node

# --- Between-wave shrines (ideate 2.1) ---
# A chance of a year-priced offer after each cleared wave, so the countdown becomes
# something the player spends deliberately and not only something that drains.
@export var shrine_chance: float = 0.6
# Never on the very first clear — the player should have felt the countdown move on
# its own before being asked to spend it.
@export var shrine_first_wave: int = 2


func _ready() -> void:
	add_to_group("wave_spawner")
	EventBus.enemy_died.connect(_on_enemy_died)
	# Start first wave after a brief delay.
	_wave_delay_timer = 1.5
	_started = true
	call_deferred("_find_arena")


func skip_next_wave() -> void:
	"""Bought from a PASSAGE shrine. The wave still counts toward the wave number and
	the boss cycle — you are paying to not fight it, not to rewind the run."""
	_skip_next_wave = true


func _find_arena() -> void:
	_arena = get_tree().get_first_node_in_group("arena")


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
				if _boss_queued:
					_spawn_boss()
					_boss_queued = false


func _start_next_wave() -> void:
	_current_wave += 1
	GameState.current_wave = _current_wave

	# A bought passage: the wave number advances (so the boss cycle keeps its
	# rhythm) but nothing spawns, and it reports as cleared immediately.
	if _skip_next_wave:
		_skip_next_wave = false
		EventBus.wave_started.emit(_current_wave, 0)
		EventBus.wave_cleared.emit(_current_wave)
		_wave_delay_timer = wave_delay
		return

	var count: int = base_enemies_per_wave + (_current_wave - 1) * enemies_per_wave_growth
	count = mini(count, max_enemies_per_wave)

	var is_boss_wave: bool = boss_every_n_waves > 0 and _current_wave % boss_every_n_waves == 0
	if is_boss_wave and boss_scene:
		# Fewer minions on a boss wave, so the boss is the fight rather than noise.
		count = maxi(2, count / 2)
		_boss_queued = true

	_spawn_queue = count
	_spawning = true
	_spawn_timer = 0.0
	EventBus.wave_started.emit(_current_wave, count + (1 if _boss_queued else 0))


func _spawn_one_enemy() -> void:
	if not enemy_scene:
		return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	enemy.global_position = _pick_spawn_position()

	# Mix of patterns, weighted toward walkers so the arena stays readable.
	# Later waves lean harder on lungers and hoppers.
	if enemy is BaseEnemy:
		(enemy as BaseEnemy).behavior = _pick_behavior()

	get_parent().add_child(enemy)
	_alive_enemies.append(enemy)


func _spawn_boss() -> void:
	if not boss_scene:
		return
	var boss: Node2D = boss_scene.instantiate() as Node2D
	boss.global_position = _pick_ground_position()
	get_parent().add_child(boss)
	_alive_enemies.append(boss)


func _pick_behavior() -> BaseEnemy.Behavior:
	var roll: float = randf()
	# Wave 1 is all walkers; the mix opens up from wave 2 onward.
	var variety: float = clampf(float(_current_wave - 1) / 4.0, 0.0, 1.0)
	if roll < 0.55 - 0.25 * variety:
		return BaseEnemy.Behavior.WALKER
	if roll < 0.8:
		return BaseEnemy.Behavior.LUNGER
	return BaseEnemy.Behavior.HOPPER


func _pick_spawn_position() -> Vector2:
	if _arena and randf() < platform_spawn_ratio:
		var platform_points: PackedVector2Array = _arena.call("get_platform_spawn_points")
		if platform_points.size() > 0:
			return platform_points[randi() % platform_points.size()]
	return _pick_ground_position()


func _pick_ground_position() -> Vector2:
	if _arena:
		var ground_points: PackedVector2Array = _arena.call("get_ground_spawn_points", 8)
		if ground_points.size() > 0:
			return ground_points[randi() % ground_points.size()]
	return Vector2(
		global_position.x + randf_range(spawn_min_x, spawn_max_x),
		global_position.y + spawn_y
	)


func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies.erase(enemy)

	# Clean up any freed references.
	var cleaned: Array[Node] = []
	for e: Node in _alive_enemies:
		if is_instance_valid(e):
			cleaned.append(e)
	_alive_enemies = cleaned

	# Check for wave clear.
	if _alive_enemies.is_empty() and not _spawning and not _boss_queued and _current_wave > 0:
		EventBus.wave_cleared.emit(_current_wave)
		_wave_delay_timer = wave_delay
		_maybe_spawn_shrine()


func _maybe_spawn_shrine() -> void:
	"""Offer a year-priced choice in the gap between waves.

	The delay before the next wave is short, but the shrine survives it and only
	disappears when the next wave actually starts — so the decision can be made while
	walking to it rather than against a timer."""
	if _current_wave < shrine_first_wave:
		return
	if randf() > shrine_chance:
		return

	var shrine: YearShrine = YearShrine.new()
	# Rest is the common offer; a passage is the rarer, steeper one.
	shrine.kind = YearShrine.Kind.PASSAGE if randf() < 0.35 else YearShrine.Kind.REST
	shrine.global_position = _pick_ground_position()
	get_parent().add_child(shrine)
