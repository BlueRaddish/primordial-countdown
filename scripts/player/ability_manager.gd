# ability_manager.gd
# Manages player abilities derived from current trait state.
# Handles Q/E/R skill slots, skill unlock detection, and skill activation.
class_name AbilityManager
extends Node

# Skill slots: [Q, E, R]. null = empty slot.
var skill_slots: Array = [null, null, null]
var slot_cooldowns: Array[float] = [0.0, 0.0, 0.0]

# All defined skills (loaded from SkillDefinitions).
var all_skills: Array[SkillData] = []

# Currently unlocked skills (conditions met by current traits).
var available_skills: Array[SkillData] = []

# Previously unlocked set — to detect newly unlocked skills.
var _previously_available: Array[SkillData] = []

# Parent player reference.
var _player: CharacterBody2D


func _ready() -> void:
	all_skills = SkillDefinitions.get_all_skills()
	_player = get_parent() as CharacterBody2D
	EventBus.trait_changed.connect(_on_trait_changed)


func _process(delta: float) -> void:
	# Tick cooldowns.
	for i: int in range(3):
		if slot_cooldowns[i] > 0.0:
			slot_cooldowns[i] = maxf(slot_cooldowns[i] - delta, 0.0)


func _on_trait_changed(_trait_name: String, _new_stage: int) -> void:
	refresh_available_skills()


func refresh_available_skills() -> void:
	"""Re-evaluate which skills are unlocked based on current trait states."""
	var trait_mgr: TraitManager = _get_trait_manager()
	if not trait_mgr:
		return

	var old_available: Array[SkillData] = available_skills.duplicate()
	available_skills.clear()

	for skill: SkillData in all_skills:
		if skill.is_unlocked(trait_mgr.traits):
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
	skill_slots[slot_index] = skill
	slot_cooldowns[slot_index] = 0.0
	EventBus.skill_assigned.emit(slot_index, skill)


func unassign_skill(slot_index: int) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	skill_slots[slot_index] = null
	slot_cooldowns[slot_index] = 0.0
	EventBus.skill_assigned.emit(slot_index, null)


func activate_skill(slot_index: int) -> void:
	"""Activate the skill in the given slot (0=Q, 1=E, 2=R)."""
	if slot_index < 0 or slot_index > 2:
		return
	if skill_slots[slot_index] == null:
		return
	if slot_cooldowns[slot_index] > 0.0:
		return

	var skill: SkillData = skill_slots[slot_index] as SkillData
	slot_cooldowns[slot_index] = skill.cooldown

	# Execute the skill: deal damage in AoE.
	_execute_skill(skill)


func _execute_skill(skill: SkillData) -> void:
	"""Deal AoE damage and show visualization."""
	if not _player:
		return

	var aim_dir: Vector2 = Vector2.RIGHT
	if _player.has_method("get_aim_direction"):
		aim_dir = _player.get_aim_direction()

	var center: Vector2 = _player.global_position
	if skill.is_directional:
		center += aim_dir * skill.aoe_radius * 0.6

	# Find all enemies in AoE radius.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy_node: Node in enemies:
		var enemy: Node2D = enemy_node as Node2D
		if not enemy or not enemy_node.is_in_group("enemies"):
			continue
		var dist: float = center.distance_to(enemy.global_position)
		if dist <= skill.aoe_radius:
			var knockback_dir: Vector2 = (enemy.global_position - _player.global_position).normalized()
			if knockback_dir.length_squared() < 0.01:
				knockback_dir = aim_dir
			EventBus.enemy_hit.emit(enemy_node, skill.damage, knockback_dir)
			hit_count += 1

	if hit_count > 0:
		EventBus.attack_landed.emit(hit_count)

	# Show AoE visualization.
	_show_aoe(center, skill.aoe_radius, skill.aoe_color, skill.is_directional, aim_dir)


func _show_aoe(center: Vector2, radius: float, color: Color, directional: bool, aim_dir: Vector2) -> void:
	"""Create an AoE indicator at the given position."""
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
	var skill: SkillData = get_skill_in_slot(slot_index)
	if skill == null or skill.cooldown <= 0.0:
		return 0.0
	return slot_cooldowns[slot_index] / skill.cooldown


func _get_trait_manager() -> TraitManager:
	if _player and _player.has_node("TraitManager"):
		return _player.get_node("TraitManager") as TraitManager
	return null
