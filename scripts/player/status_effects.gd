# status_effects.gd
# Timed self-buffs on the player. Child node of Player.
#
# PLANNING1 section 6: full loss of a trait grants one buff. The buff softens the
# fall, it does not reverse it — every effect here is temporary and on a cooldown.
#
# Buffs are stored as instances and the aggregate is recomputed every frame, so
# expiry never has to "undo" anything.
class_name StatusEffects
extends Node


class ActiveBuff extends RefCounted:
	var id: String = ""
	var duration: float = 1.0
	var time_left: float = 1.0
	var color: Color = Color.WHITE

	# Aggregate contributions. Neutral values leave the aggregate untouched.
	var damage_mult: float = 1.0
	var damage_taken_mult: float = 1.0
	var omnivamp: float = 0.0
	var contact_retaliation: float = 0.0
	var attack_cooldown_mult: float = 1.0

	# Periodic pulse (Echo Sense).
	var pulse_damage: float = 0.0
	var pulse_radius: float = 0.0
	var pulse_interval: float = 0.0
	var pulse_timer: float = 0.0


# How often a thorns aura is allowed to hurt the same crowd.
const RETALIATION_TICK: float = 0.5
const RETALIATION_RADIUS: float = 26.0

var _buffs: Array[ActiveBuff] = []
var _retaliation_timer: float = 0.0

# Cached aggregates, rebuilt in _process.
var _damage_mult: float = 1.0
var _damage_taken_mult: float = 1.0
var _omnivamp: float = 0.0
var _contact_retaliation: float = 0.0
var _attack_cooldown_mult: float = 1.0

var _player: CharacterBody2D


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_recompute()


func _process(delta: float) -> void:
	if _buffs.is_empty():
		_retaliation_timer = 0.0
		return

	var expired: Array[ActiveBuff] = []
	for buff: ActiveBuff in _buffs:
		buff.time_left -= delta
		if buff.time_left <= 0.0:
			expired.append(buff)
			continue
		_tick_pulse(buff, delta)

	for buff: ActiveBuff in expired:
		_buffs.erase(buff)
		EventBus.buff_expired.emit(buff.id)

	_recompute()
	_tick_retaliation(delta)


# ---- Public API ----

func apply_buff(skill: SkillData) -> void:
	"""Apply (or refresh) the buff carried by a skill. Re-casting refreshes rather than stacks."""
	if skill.buff_duration <= 0.0:
		return

	var existing: ActiveBuff = _find(skill.skill_name)
	var buff: ActiveBuff = existing if existing else ActiveBuff.new()

	buff.id = skill.skill_name
	buff.duration = skill.buff_duration
	buff.time_left = skill.buff_duration
	buff.color = skill.aoe_color
	buff.damage_mult = skill.buff_damage_mult
	buff.damage_taken_mult = skill.buff_damage_taken_mult
	buff.omnivamp = skill.buff_omnivamp
	buff.contact_retaliation = skill.buff_contact_retaliation
	buff.attack_cooldown_mult = skill.buff_attack_cooldown_mult
	buff.pulse_damage = skill.buff_pulse_damage
	buff.pulse_radius = skill.buff_pulse_radius
	buff.pulse_interval = skill.buff_pulse_interval
	buff.pulse_timer = 0.0

	if not existing:
		_buffs.append(buff)

	_recompute()
	EventBus.buff_applied.emit(buff.id, buff.duration, buff.color)


func clear_all() -> void:
	_buffs.clear()
	_recompute()


func has_buff(id: String) -> bool:
	return _find(id) != null


func get_active_buffs() -> Array[ActiveBuff]:
	return _buffs


func get_damage_mult() -> float:
	return _damage_mult


func get_damage_taken_mult() -> float:
	return _damage_taken_mult


func get_omnivamp() -> float:
	return _omnivamp


func get_attack_cooldown_mult() -> float:
	return _attack_cooldown_mult


func is_invulnerable() -> bool:
	return _damage_taken_mult <= 0.001


# ---- Internals ----

func _find(id: String) -> ActiveBuff:
	for buff: ActiveBuff in _buffs:
		if buff.id == id:
			return buff
	return null


func _recompute() -> void:
	_damage_mult = 1.0
	_damage_taken_mult = 1.0
	_omnivamp = 0.0
	_contact_retaliation = 0.0
	_attack_cooldown_mult = 1.0

	for buff: ActiveBuff in _buffs:
		_damage_mult *= buff.damage_mult
		_damage_taken_mult *= buff.damage_taken_mult
		# Strongest source wins rather than stacking — keeps buffs from compounding
		# into the "game breaking" territory PLANNING1 rules out.
		_omnivamp = maxf(_omnivamp, buff.omnivamp)
		_contact_retaliation = maxf(_contact_retaliation, buff.contact_retaliation)
		_attack_cooldown_mult = minf(_attack_cooldown_mult, buff.attack_cooldown_mult)


func _tick_pulse(buff: ActiveBuff, delta: float) -> void:
	if buff.pulse_damage <= 0.0 or buff.pulse_interval <= 0.0 or not _player:
		return

	buff.pulse_timer -= delta
	if buff.pulse_timer > 0.0:
		return
	buff.pulse_timer = buff.pulse_interval

	var origin: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	var hits: int = _damage_enemies_near(origin, buff.pulse_radius, buff.pulse_damage, 90.0)

	var indicator: AoEIndicator = AoEIndicator.new()
	indicator.aoe_center = origin
	indicator.aoe_radius = buff.pulse_radius
	indicator.aoe_color = buff.color
	indicator.is_directional = false
	_player.get_parent().add_child(indicator)

	if hits > 0 and _player.has_method("report_damage_dealt"):
		_player.call("report_damage_dealt", buff.pulse_damage * float(hits))


func _tick_retaliation(delta: float) -> void:
	if _contact_retaliation <= 0.0 or not _player:
		return

	_retaliation_timer -= delta
	if _retaliation_timer > 0.0:
		return

	var origin: Vector2 = _player.global_position + Vector2(0.0, -10.0)
	var hits: int = _damage_enemies_near(origin, RETALIATION_RADIUS, _contact_retaliation, 140.0)
	if hits > 0:
		_retaliation_timer = RETALIATION_TICK
		if _player.has_method("report_damage_dealt"):
			_player.call("report_damage_dealt", _contact_retaliation * float(hits))


func _damage_enemies_near(origin: Vector2, radius: float, damage: float, knockback: float) -> int:
	var hits: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if not enemy or not enemy.has_method("take_damage"):
			continue
		if origin.distance_to(enemy.global_position) > radius:
			continue
		var dir: Vector2 = (enemy.global_position - origin).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector2.RIGHT
		enemy.call("take_damage", damage, Vector2(dir.x * knockback, -knockback * 0.4))
		hits += 1
	return hits
