# ability_manager.gd
# Manages player abilities derived from current trait state.
# Handles Q/E/R skill slots, skill unlock detection, and skill activation.
#
# Skills are never bought or found. They appear and disappear purely as a function
# of what the player can currently do, which is TraitManager's job to know.
class_name AbilityManager
extends Node

# Skill slots: [Q, E, R]. null = empty slot.
var skill_slots: Array = [null, null, null]
var slot_cooldowns: Array[float] = [0.0, 0.0, 0.0]

# All defined skills (loaded from SkillDefinitions).
var all_skills: Array[SkillData] = []

# Currently unlocked skills (conditions met by current traits).
var available_skills: Array[SkillData] = []

# --- Loadout lock ---
# Reassigning skills is only allowed in the window right after learning a new one.
# Without this the character screen is a free mid-fight loadout swap — pause, slot
# whatever counters the thing currently killing you, unpause — which drains the
# tension out of every hard moment and makes the trait-driven kit meaningless.
# Filling an EMPTY slot is always allowed; that is how a skill first lands.
var _reassign_window_open: bool = false

# Preloaded rather than referenced by class_name: a newly declared global class is
# invisible to a headless run until the editor rescans.
const SweepIndicator := preload("res://scripts/player/sweep_indicator.gd")
const Vfx := preload("res://scripts/vfx/vfx.gd")

# --- Travelling hitbox state (see _begin_sweep) ---
var _sweep_skill: SkillData = null
var _sweep_timer: float = 0.0
var _sweep_hit: Array[Node] = []

# Parent player reference.
var _player: CharacterBody2D


func _ready() -> void:
	all_skills = SkillDefinitions.get_all_skills()
	_player = get_parent() as CharacterBody2D
	EventBus.trait_changed.connect(_on_trait_changed)
	# An evolved trait growing unlocks its skills (Wing Dash, Curl, ...).
	EventBus.evolved_trait_grown.connect(_on_evolved_trait_grown)
	call_deferred("refresh_available_skills")


func _process(delta: float) -> void:
	# Tick cooldowns.
	for i: int in range(3):
		if slot_cooldowns[i] > 0.0:
			slot_cooldowns[i] = maxf(slot_cooldowns[i] - delta, 0.0)

	if _sweep_skill != null:
		_tick_sweep(delta)


func _on_trait_changed(_trait_name: String, _new_stage: int) -> void:
	refresh_available_skills()


func _on_evolved_trait_grown(_evolved_id: String) -> void:
	refresh_available_skills()


func refresh_available_skills() -> void:
	"""Re-evaluate which skills are unlocked based on current trait states."""
	var trait_mgr: TraitManager = _get_trait_manager()
	if not trait_mgr:
		return

	# Base trait stages, plus evolved traits folded in as pseudo-traits (wings/hide
	# as stage 0 dormant / 1 grown) so skills can key off them.
	var states: Dictionary = trait_mgr.traits.duplicate()
	var evolved_mgr: Node = _get_evolved_manager()
	if evolved_mgr:
		var evolved_states: Dictionary = evolved_mgr.call("get_evolved_states")
		for id: String in evolved_states:
			states[id] = evolved_states[id]

	var old_available: Array[SkillData] = available_skills.duplicate()
	available_skills.clear()

	for skill: SkillData in all_skills:
		if skill.is_unlocked(states):
			available_skills.append(skill)

	# Detect newly unlocked skills and emit signal for popup.
	for skill: SkillData in available_skills:
		var was_available: bool = false
		for old_skill: SkillData in old_available:
			if old_skill.skill_name == skill.skill_name:
				was_available = true
				break
		if not was_available:
			# Learning something new is the one moment the loadout opens up.
			_reassign_window_open = true
			EventBus.skill_unlocked.emit(skill)

	# Remove skills that are no longer unlocked from slots.
	for i: int in range(3):
		if skill_slots[i] != null:
			var slot_skill: SkillData = skill_slots[i] as SkillData
			var still_valid: bool = false
			for avail: SkillData in available_skills:
				if avail.skill_name == slot_skill.skill_name:
					still_valid = true
					break
			if not still_valid:
				skill_slots[i] = null
				slot_cooldowns[i] = 0.0
				EventBus.skill_assigned.emit(i, null)


func can_reassign() -> bool:
	"""True while the player is allowed to change an occupied slot."""
	return _reassign_window_open


func _loadout_editable() -> bool:
	"""The lock, plus the testing escape hatch. Exercising a skill means being able to
	put it in a slot on demand rather than devolving until the game grants it."""
	return _reassign_window_open or GameState.show_dev_tools


func close_reassign_window() -> void:
	"""Lock the loadout again. Called when the skill editor is dismissed."""
	_reassign_window_open = false


func assign_skill(slot_index: int, skill: SkillData) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	# Occupied slots are locked outside the post-unlock window. An empty slot can
	# always be filled, so a newly learned skill is never stranded.
	#
	# The window is NOT closed here: the loadout editor needs to make several edits
	# in one sitting, so closing it is an explicit call (close_reassign_window) made
	# when that screen is dismissed.
	if skill_slots[slot_index] != null and not _loadout_editable():
		return
	# Remove skill from other slots if already assigned.
	for i: int in range(3):
		if skill_slots[i] != null:
			var existing: SkillData = skill_slots[i] as SkillData
			if existing.skill_name == skill.skill_name:
				skill_slots[i] = null
				slot_cooldowns[i] = 0.0
				EventBus.skill_assigned.emit(i, null)
	skill_slots[slot_index] = skill
	slot_cooldowns[slot_index] = 0.0
	EventBus.skill_assigned.emit(slot_index, skill)


func unassign_skill(slot_index: int) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	if not _loadout_editable():
		return
	skill_slots[slot_index] = null
	slot_cooldowns[slot_index] = 0.0
	EventBus.skill_assigned.emit(slot_index, null)


func auto_assign(skill: SkillData) -> int:
	"""Drop a skill into the first free slot. Returns the slot used, or -1."""
	for i: int in range(3):
		if skill_slots[i] == null:
			assign_skill(i, skill)
			return i
	return -1


func activate_skill(slot_index: int) -> void:
	"""Activate the skill in the given slot (0=Q, 1=E, 2=R)."""
	if slot_index < 0 or slot_index > 2:
		return
	if skill_slots[slot_index] == null:
		return
	if slot_cooldowns[slot_index] > 0.0:
		return

	var skill: SkillData = skill_slots[slot_index] as SkillData
	slot_cooldowns[slot_index] = 0.0 if GameState.no_skill_cooldown else skill.cooldown

	# Skills are paid for in years off the countdown. Free skills (Pounce) charge
	# nothing, because the player has no alternative once the legs are gone.
	if skill.year_cost > 0.0:
		EventBus.skill_cost_paid.emit(skill.year_cost)

	_execute_skill(skill)


func _execute_skill(skill: SkillData) -> void:
	if not _player:
		return

	var aim_dir: Vector2 = Vector2.RIGHT
	if _player.has_method("get_aim_direction"):
		aim_dir = _player.call("get_aim_direction")

	# 1. Offensive component.
	#
	# A skill that both hits AND moves you gets a hitbox that TRAVELS WITH YOU for the
	# duration of the impulse, rather than one AoE resolved at the cast point. Landing
	# it once on departure meant a Wing Dash flew straight through an enemy without
	# touching it — no damage, and more importantly no knockback, so you ended the dash
	# standing inside something that then hit you. The dash read as a way to hurt
	# yourself.
	#
	# Reversed impulses (Backstep Slash) are excluded on purpose: there the strike
	# lands where you were while the movement carries you away, which is the whole
	# shape of the move.
	var sweeps: bool = (
		skill.aoe_damage > 0.0
		and skill.impulse_speed > 0.0
		and not skill.impulse_reverse
	)

	if sweeps:
		_begin_sweep(skill, aim_dir)
	elif skill.aoe_damage > 0.0:
		_execute_offensive(skill, aim_dir)
	else:
		# Buff and movement skills get the cast punctuation instead of a hit area,
		# since they have no area that hurts anything.
		_show_cast(skill)

	# 2. Buff component.
	if skill.buff_duration > 0.0:
		var status: StatusEffects = _get_status_effects()
		if status:
			status.apply_buff(skill)

	# 3. Impulse component (alternative movement). A reversed impulse carries the
	# player away from the cursor while the attack above still lands toward it — the
	# shape of a back-step strike.
	if skill.impulse_speed > 0.0 and _player.has_method("apply_impulse"):
		var move_dir: Vector2 = -aim_dir if skill.impulse_reverse else aim_dir
		_player.call("apply_impulse", move_dir, skill.impulse_speed, skill.impulse_upward_bias)

	# 4. Status component for skills with no damage of their own — a buff or a dash
	# that still leaves something on everything around you.
	if skill.status_radius > 0.0 and skill.has_status():
		_apply_status_in_radius(skill)

	EventBus.skill_used.emit(skill)


# ---- Travelling hitbox (dash-attacks) ----

func _begin_sweep(skill: SkillData, aim_dir: Vector2) -> void:
	_sweep_skill = skill
	_sweep_hit.clear()
	_sweep_timer = 0.0
	if _player.has_method("get_impulse_time"):
		_sweep_timer = _player.call("get_impulse_time")
	if _sweep_timer <= 0.0:
		_sweep_timer = 0.25
	# A visual that FOLLOWS the player, rather than one flash at the cast point. A
	# static burst was actively misleading here: it drew a circle where the dash began
	# while the damage was happening somewhere else, so there was no way to see that
	# the hitbox travelled at all, or how far it reached.
	var sweep_vis: SweepIndicator = SweepIndicator.new()
	sweep_vis.target = _player
	sweep_vis.radius = skill.aoe_radius
	sweep_vis.color = skill.aoe_color
	sweep_vis.duration = _sweep_timer
	_player.get_parent().add_child(sweep_vis)

	# Tick once immediately so anything already in reach is hit on the frame the
	# skill fires, not one frame later.
	_tick_sweep(0.0)


func _tick_sweep(delta: float) -> void:
	if _sweep_skill == null or not _player:
		return
	_sweep_timer -= delta

	var center: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	var damage: float = _sweep_skill.aoe_damage
	var status: StatusEffects = _get_status_effects()
	if status:
		damage *= status.get_damage_mult()

	var hit_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if not enemy or not enemy.has_method("take_damage"):
			continue
		# Once per cast, however long the dash passes through something.
		if _sweep_hit.has(enemy):
			continue
		if center.distance_to(enemy.global_position) > _sweep_skill.aoe_radius:
			continue
		_sweep_hit.append(enemy)

		var kb_dir: Vector2 = (enemy.global_position - center).normalized()
		if kb_dir.length_squared() < 0.01:
			kb_dir = Vector2.RIGHT
		enemy.call("take_damage", damage, Vector2(kb_dir.x * 220.0, -90.0))
		_sweep_skill.apply_status_to(enemy)
		# A spark on each target as the sweep passes through it, so a connect is
		# distinguishable from a near miss at speed.
		Vfx.impact(
			_player.get_parent(),
			enemy.global_position + Vector2(0.0, -10.0),
			kb_dir,
			_sweep_skill.aoe_color
		)
		hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)
		if _player.has_method("report_damage_dealt"):
			_player.call("report_damage_dealt", damage * float(hit_count))

	if _sweep_timer <= 0.0:
		_sweep_skill = null
		_sweep_hit.clear()


func _apply_status_in_radius(skill: SkillData) -> void:
	var origin: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if not enemy:
			continue
		if origin.distance_to(enemy.global_position) > skill.status_radius:
			continue
		skill.apply_status_to(enemy)


func _execute_offensive(skill: SkillData, aim_dir: Vector2) -> void:
	var center: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	if skill.is_directional:
		center += aim_dir * skill.aoe_radius * 0.6

	var damage: float = skill.aoe_damage
	var status: StatusEffects = _get_status_effects()
	if status:
		damage *= status.get_damage_mult()

	var hit_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if not enemy or not enemy.has_method("take_damage"):
			continue
		if center.distance_to(enemy.global_position) > skill.aoe_radius:
			continue
		var kb_dir: Vector2 = (enemy.global_position - _player.global_position).normalized()
		if kb_dir.length_squared() < 0.01:
			kb_dir = aim_dir
		enemy.call("take_damage", damage, Vector2(kb_dir.x * 220.0, -90.0))
		Vfx.impact(
			_player.get_parent(), enemy.global_position + Vector2(0.0, -10.0),
			kb_dir, skill.aoe_color
		)
		# Statuses land after the damage, so a skill that both hits and leaves the
		# target reeling does not amplify its own hit — the setup is for what comes
		# next, which is what makes it a combo rather than a bigger number.
		skill.apply_status_to(enemy)
		hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)
		if _player.has_method("report_damage_dealt"):
			_player.call("report_damage_dealt", damage * float(hit_count))

	# Note: offensive skills do NOT also emit attack_made. They already paid their
	# own year_cost in activate_skill, and charging both would double-bill them.
	_show_aoe(center, skill.aoe_radius, skill.aoe_color, skill.is_directional, aim_dir)


func _show_cast(skill: SkillData) -> void:
	"""Punctuation on the player when a skill fires. Buffs get rising motes, so a
	self-buff never reads the same as an attack going off."""
	var at: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	Vfx.cast(_player.get_parent(), at, skill.aoe_color, maxf(skill.aoe_radius, 20.0))
	if skill.buff_duration >= 1.0:
		Vfx.buff(_player.get_parent(), at, skill.aoe_color)


func _show_aoe(center: Vector2, radius: float, color: Color, directional: bool, aim_dir: Vector2) -> void:
	if not _player:
		return
	# The true hit area drawn solid, with the flourish over it — so a skill's real
	# reach is legible instead of being implied by a burst that overshoots it.
	var hb: Node2D = Vfx.hitbox(_player.get_parent(), center)
	if hb:
		hb.set("color", color)
		hb.set("radius", radius)
		hb.set("lifetime", 0.24)
		if directional:
			hb.set("shape", 2) # VfxHitbox.Shape.ARC
			hb.set("angle", aim_dir.angle())
	Vfx.aoe(_player.get_parent(), center, color, radius)


func get_skill_in_slot(slot_index: int) -> SkillData:
	if slot_index < 0 or slot_index > 2:
		return null
	if skill_slots[slot_index] == null:
		return null
	return skill_slots[slot_index] as SkillData


func get_cooldown_fraction(slot_index: int) -> float:
	"""Returns 0.0 (ready) to 1.0 (full cooldown)."""
	if slot_index < 0 or slot_index > 2:
		return 0.0
	if GameState.no_skill_cooldown:
		return 0.0
	var skill: SkillData = get_skill_in_slot(slot_index)
	if skill == null or skill.cooldown <= 0.0:
		return 0.0
	return slot_cooldowns[slot_index] / skill.cooldown


func _get_trait_manager() -> TraitManager:
	if _player and _player.has_node("TraitManager"):
		return _player.get_node("TraitManager") as TraitManager
	return null


func _get_evolved_manager() -> Node:
	if _player and _player.has_node("EvolvedTraitManager"):
		return _player.get_node("EvolvedTraitManager")
	return null


func _get_status_effects() -> StatusEffects:
	if _player and _player.has_node("StatusEffects"):
		return _player.get_node("StatusEffects") as StatusEffects
	return null
