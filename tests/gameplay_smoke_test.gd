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
	_check_loadout_lock()
	_check_evolved_takes_slot()
	await _check_dash_attack_sweeps()
	await _check_air_skill_hang()
	await _check_run_ends_when_fully_devolved()

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


# ---- Dash-attacks ----

func _check_dash_attack_sweeps() -> void:
	"""A skill that hits AND moves must damage what it travels through, not only what
	was in range at the cast point. Otherwise a Wing Dash flies through an enemy
	without touching it — no damage and, worse, no knockback, leaving you parked
	inside something that immediately hits you."""
	# Degrading traits above unlocked skills, which opens the loadout editor and pauses
	# the tree — and a paused tree does not tick the sweep. Drain it first; the editor
	# queues one screen per newly learned skill, so closing once is not enough.
	var editor: Node = get_tree().root.find_child("PopupControl", true, false)
	for i: int in range(10):
		if editor and editor.visible:
			editor.call("_close")
		await get_tree().physics_frame

	var am: AbilityManager = _player.get_node("AbilityManager") as AbilityManager
	var dash_skill: SkillData = null
	for s: SkillData in SkillDefinitions.get_all_skills():
		if s.skill_name == "Wing Dash":
			dash_skill = s
	if not am or not dash_skill:
		_fail("Wing Dash not found")
		return

	# Both on the ground: the sweep is a radius around the player, so a target parked
	# 28px above or below it is out of reach for reasons that have nothing to do with
	# whether the hitbox travels.
	_player.global_position = Vector2(300, 288)
	await _wait(6)

	# Skills aim at the cursor and headless has no real mouse, so the dash can go off
	# at any angle — including diagonally, straight over a target pinned to the floor.
	# Place the target along the ACTUAL aim vector, and hold it there each frame so
	# gravity does not drop it out of the path mid-test.
	var aim: Vector2 = (_player.call("get_aim_direction") as Vector2).normalized()
	var target_pos: Vector2 = _player.global_position + aim * 55.0

	var enemy: BaseEnemy = load("res://scenes/enemies/base_enemy.tscn").instantiate() as BaseEnemy
	enemy.behavior = BaseEnemy.Behavior.WALKER
	enemy.global_position = target_pos
	get_tree().current_scene.add_child(enemy)
	await _wait(2)
	enemy.global_position = target_pos

	var start_gap: float = enemy.global_position.distance_to(_player.global_position)
	_expect(
		start_gap > dash_skill.aoe_radius,
		"target starts outside the cast-point AoE (%.0f px vs %.0f radius)"
			% [start_gap, dash_skill.aoe_radius]
	)

	var hp_before: float = enemy.get_health_fraction()
	# Closing the editor above locked the loadout again, and the editor auto-filled
	# the free slots — so an assign into an occupied slot would be silently refused
	# and we would end up firing whatever skill happened to be sitting there. Use the
	# dev override to guarantee the slot holds what this test is about.
	GameState.show_dev_tools = true
	for i: int in range(3):
		am.unassign_skill(i)
	am.assign_skill(0, dash_skill)
	GameState.show_dev_tools = false
	var slotted: SkillData = am.get_skill_in_slot(0)
	_expect(
		slotted != null and slotted.skill_name == "Wing Dash",
		"Wing Dash is the skill actually being fired"
	)
	am.activate_skill(0)
	for i: int in range(20):
		await get_tree().physics_frame
		if not is_instance_valid(enemy):
			break
		enemy.global_position = target_pos

	if not is_instance_valid(enemy):
		_expect(true, "dash-attack hit the enemy it travelled through (killed it)")
		return
	_expect(
		enemy.get_health_fraction() < hp_before,
		"dash-attack damages what it travels through (%.2f -> %.2f)"
			% [hp_before, enemy.get_health_fraction()]
	)
	enemy.queue_free()


# ---- End of run ----

func _check_run_ends_when_fully_devolved() -> void:
	"""Degrading the LAST remaining trait must end the run.

	It did not: the end check lived only inside `_trigger_devolution()`, which becomes
	unreachable once `total_devolutions` hits the 14-step cap. The final devolution
	resolved normally and then nothing ever asked again, so the game carried on at 0
	years with every trait fully lost."""
	var devo: Node = get_tree().get_first_node_in_group("devolution_system")
	var tm: TraitManager = _player.get_node("TraitManager") as TraitManager
	if not devo or not tm:
		_fail("no devolution system / trait manager")
		return

	var ended: Array[bool] = [false]
	var on_died: Callable = func() -> void: ended[0] = true
	EventBus.player_died.connect(on_died)

	# Everything gone except one last stage on the very last trait.
	for tname: String in TraitManager.ALL_TRAITS:
		tm.set_trait_stage(tname, TraitManager.MAX_STAGE)
	tm.set_trait_stage("head", TraitManager.STAGE_PARTIAL)
	_expect(not ended[0], "run is still alive with one degradation left")

	# Take it. This is the exact step that used to leave the game running forever.
	devo.call("apply_devolution", "head", tm)
	_expect(ended[0], "run ENDS when the last trait is fully lost")

	EventBus.player_died.disconnect(on_died)


# ---- Aerial hang ----

func _check_air_skill_hang() -> void:
	"""Firing a skill in mid-air buys a brief float, so an aerial chain leaves time to
	read where it put you instead of dropping straight back to terminal velocity."""
	var hang: float = _player.get("air_skill_hang_time")
	var cap: float = (_player.get("max_fall_speed") as float) * 0.3

	# Baseline: fall freely from height and record the speed reached.
	_player.global_position = Vector2(320, 120)
	_player.velocity = Vector2.ZERO
	await _wait(14)
	var free_fall: float = _player.velocity.y

	# Now the same fall, but with a skill fired on the way down.
	_player.global_position = Vector2(320, 120)
	_player.velocity = Vector2.ZERO
	await _wait(8)
	EventBus.skill_used.emit(SkillDefinitions.get_all_skills()[0])
	await _wait(4)
	var hung: float = _player.velocity.y

	_expect(hang > 0.0, "aerial hang is configured (%.2fs)" % hang)
	_expect(
		hung < free_fall,
		"an aerial skill slows the fall (%.0f vs %.0f free-fall)" % [hung, free_fall]
	)
	_expect(hung <= cap + 1.0, "hang caps descent at %.0f (got %.0f)" % [cap, hung])


# ---- Loadout lock ----

func _check_loadout_lock() -> void:
	"""Occupied slots are locked outside the post-unlock window — except with dev
	tools on, where a tester must be able to slot a skill on demand."""
	var am: AbilityManager = _player.get_node("AbilityManager") as AbilityManager
	var skills: Array[SkillData] = SkillDefinitions.get_all_skills()
	if not am or skills.size() < 2:
		_fail("no ability manager / skills")
		return

	GameState.show_dev_tools = false
	am.close_reassign_window()
	for i: int in range(3):
		am.unassign_skill(i)

	am.assign_skill(0, skills[0])
	_expect(am.get_skill_in_slot(0) != null, "an empty slot fills even while locked")

	am.assign_skill(0, skills[1])
	_expect(
		am.get_skill_in_slot(0).skill_name == skills[0].skill_name,
		"an occupied slot is locked in normal play"
	)

	GameState.show_dev_tools = true
	am.assign_skill(0, skills[1])
	_expect(
		am.get_skill_in_slot(0).skill_name == skills[1].skill_name,
		"an occupied slot is editable with dev tools on"
	)
	am.unassign_skill(0)
	_expect(am.get_skill_in_slot(0) == null, "unassign works with dev tools on")
	GameState.show_dev_tools = false


# ---- Evolved traits ----

func _check_evolved_takes_slot() -> void:
	"""A grown evolved trait owns the base trait's slot, which is what lets the
	character screen show it in that trait's row instead of in a separate list."""
	var em: Node = _player.get_node_or_null("EvolvedTraitManager")
	var tm: TraitManager = _player.get_node("TraitManager") as TraitManager
	if not em or not tm:
		_fail("no evolved/trait manager")
		return

	_expect(em.call("get_slot_owner", "arms") == null, "arms slot starts unowned")

	tm.set_trait_stage("arms", TraitManager.STAGE_LOST)
	tm.set_trait_stage("skin", TraitManager.STAGE_LOST)
	em.call("grow", "claws")

	var owner_data: EvolvedTraitData = em.call("get_slot_owner", "arms")
	_expect(owner_data != null and owner_data.id == "claws", "claws owns the arms slot")
	_expect(em.call("get_slot_owner", "legs") == null, "an untouched slot stays unowned")
	# Same-slot exclusivity: growing claws must close wings off for good.
	var blocker: EvolvedTraitData = em.call("get_blocker", "wings")
	_expect(blocker != null and blocker.id == "claws", "wings closed off by claws")


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
