# gameplay_smoke_test.gd
# Checks the things that are easy to get wrong and impossible to see by reading:
# platform collision flags, whether an enemy can escape from under a shelf, the dash's
# i-frames, and whether the first boss is actually winnable.
#
# Run:
#   godot --headless --path . res://tests/gameplay_smoke_test.tscn
# Exit code is non-zero if any check failed.
extends Node

var _failures: int = 0
var _player: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(load("res://scenes/main/game.tscn").instantiate())
	_run()


func _run() -> void:
	await _wait(20)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if not _player:
		_fail("no player")
		get_tree().quit(1)
		return

	_check_platforms()
	_check_boss_math()
	await _check_dash()
	await _check_enemy_not_trapped()

	print("[gameplay] FAILURES: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ---- Platforms ----

func _check_platforms() -> void:
	"""Every floating platform must be one-way, or it blocks jumps from beneath and
	traps enemies under it."""
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if not arena:
		_fail("no arena node")
		return
	var checked: int = 0
	for child: Node in arena.get_children():
		if not child.name.begins_with("Platform"):
			continue
		var body: StaticBody2D = child as StaticBody2D
		if not body:
			continue
		for sub: Node in body.get_children():
			var shape: CollisionShape2D = sub as CollisionShape2D
			if not shape:
				continue
			checked += 1
			if not shape.one_way_collision:
				_fail("%s is SOLID — blocks jumps from below" % child.name)
	_expect(checked >= 11, "found all platform colliders (got %d)" % checked)
	if _failures == 0:
		print("[gameplay] ok all %d platforms are one-way" % checked)


# ---- Boss ----

func _check_boss_math() -> void:
	"""The first boss has to be beatable with what a wave-3 player actually has:
	100 HP, intact skin (x0.8 taken), a 25-damage swing, and no skills."""
	var boss: BossEnemy = load("res://scenes/enemies/boss_enemy.tscn").instantiate() as BossEnemy
	if not boss:
		_fail("boss scene did not instantiate as BossEnemy")
		return

	var swings: int = int(ceil(boss.max_health / 25.0))
	var slam_taken: float = boss.slam_damage * 0.8
	var strike_taken: float = boss.strike_damage * 0.8
	var slams_to_die: int = int(ceil(100.0 / slam_taken))
	var strikes_to_die: int = int(ceil(100.0 / strike_taken))

	print("[gameplay] boss: %d HP = %d swings | slam %.0f (%d to kill you) | strike %.0f (%d)" % [
		int(boss.max_health), swings, slam_taken, slams_to_die, strike_taken, strikes_to_die
	])

	_expect(swings <= 12, "boss dies in <=12 swings (got %d)" % swings)
	_expect(slams_to_die >= 3, "survives >=3 slams (got %d)" % slams_to_die)
	_expect(strikes_to_die >= 5, "survives >=5 strikes (got %d)" % strikes_to_die)
	# The telegraph contract: the attack you get most warning about must hurt most.
	_expect(
		boss.slam_damage > boss.strike_damage and boss.strike_damage > boss.contact_damage,
		"damage order slam > strike > contact"
	)
	boss.free()


# ---- Dash ----

func _check_dash() -> void:
	_player.global_position = Vector2(400, 200)
	await _wait(4)

	var start_x: float = _player.global_position.x
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")

	_expect(_player.call("is_dashing"), "dash activates")

	# i-frames: damage during a dash must be refused entirely.
	var hp_before: float = GameState.player_health
	_player.call("take_damage", 25.0, Vector2.RIGHT)
	await get_tree().physics_frame
	_expect(
		is_equal_approx(GameState.player_health, hp_before),
		"dash grants i-frames (hp %.1f -> %.1f)" % [hp_before, GameState.player_health]
	)

	await _wait(12)
	var moved: float = absf(_player.global_position.x - start_x)
	_expect(moved > 20.0, "dash actually moves you (%.1f px)" % moved)
	_expect(not _player.call("is_dashing"), "dash ends")


# ---- Enemies under a shelf ----

func _check_enemy_not_trapped() -> void:
	"""Platform 0 sits 9px above the ground — an enemy is 20px tall, so with a solid
	collider anything that walked under it was stuck. One-way collision should let it
	walk straight through."""
	var enemy_scene: PackedScene = load("res://scenes/enemies/base_enemy.tscn")
	var enemy: BaseEnemy = enemy_scene.instantiate() as BaseEnemy
	enemy.behavior = BaseEnemy.Behavior.WALKER
	# Directly under the leftmost shelf (x 126..216).
	enemy.global_position = Vector2(170, 288)
	get_tree().current_scene.add_child(enemy)

	# Player just past the shelf's right edge (216) and inside detection_range (130),
	# so the enemy actively chases out from under it rather than idly patrolling.
	_player.global_position = Vector2(272, 280)
	var start_x: float = enemy.global_position.x

	# Poll rather than sampling once at a fixed time: the enemy interleaves chasing
	# with windup/strike/recover, so any single deadline is arbitrary.
	var escaped: bool = false
	var best_x: float = start_x
	for i: int in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(enemy):
			break
		# The player drifts once the enemy engages it; hold it in place so the test
		# measures the enemy's freedom to move, not a moving target.
		_player.global_position.x = 272.0
		best_x = maxf(best_x, enemy.global_position.x)
		if best_x > 216.0:
			escaped = true
			break

	_expect(escaped, "enemy walks out from under the shelf (x %.0f -> %.0f)" % [start_x, best_x])
	if is_instance_valid(enemy):
		enemy.queue_free()


# ---- Helpers ----

func _expect(condition: bool, what: String) -> void:
	if condition:
		print("[gameplay] ok %s" % what)
	else:
		_fail(what)


func _fail(msg: String) -> void:
	_failures += 1
	printerr("[gameplay] FAIL: %s" % msg)


func _wait(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().physics_frame
