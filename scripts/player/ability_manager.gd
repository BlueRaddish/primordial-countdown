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


func assign_skill(slot_index: int, skill: SkillData) -> void:
	if slot_index < 0 or slot_index > 2:
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
	if skill.aoe_damage > 0.0:
		_execute_offensive(skill, aim_dir)
	else:
		# Buff and movement skills still show a burst centred on the player.
		_show_aoe(_player.global_position + Vector2(0.0, -10.0), skill.aoe_radius,
			skill.aoe_color, false, aim_dir)

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

	EventBus.skill_used.emit(skill)


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
		hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)
		if _player.has_method("report_damage_dealt"):
			_player.call("report_damage_dealt", damage * float(hit_count))

	# Note: offensive skills do NOT also emit attack_made. They already paid their
	# own year_cost in activate_skill, and charging both would double-bill them.
	_show_aoe(center, skill.aoe_radius, skill.aoe_color, skill.is_directional, aim_dir)


func _show_aoe(center: Vector2, radius: float, color: Color, directional: bool, aim_dir: Vector2) -> void:
	if not _player:
		return
	var indicator: AoEIndicator = AoEIndicator.new()
	indicator.aoe_center = center
	indicator.aoe_radius = radius
	indicator.aoe_color = color
	indicator.is_directional = directional
	indicator.direction = aim_dir
	# Add to game root so it stays in world space.
	_player.get_parent().add_child(indicator)


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
