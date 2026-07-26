# skill_data.gd
# Custom Resource for data-driven skill definitions.
#
# A skill is the buff PLANNING1 section 6 grants when a trait is fully lost. It is
# unlocked by trait state, never bought, and it always costs a cooldown.
#
# Unlock conditions are trait_name -> [min_stage, max_stage] with stages
# 0 = intact, 1 = partial, 2 = fully lost. A skill naming more than one trait is a
# multi-trait skill: it reads a *combination* of capability, not a single loss.
#
# Every skill can carry up to four components and applies whichever are non-zero:
#   1. Offensive  — instant AoE damage        (aoe_damage > 0)
#   2. Buff       — timed self modifiers      (buff_duration > 0)
#   3. Impulse    — alternative movement      (impulse_speed > 0)
#   4. Status     — what it leaves on enemies (status_* fields)
#
# The status component is what stops a skill from being *only* an attack, *only* a
# buff, or *only* a dash. A skill that bleeds what it hits, or slows what it passes
# through, or leaves a target reeling for the next thing you do, reaches into the
# rest of the kit instead of resolving on its own. Two of them chain by design:
#
#   * Reeling raises all incoming damage on that enemy, so anything that applies it
#     is a setup for whatever you fire next (BaseEnemy.take_damage reads it).
#   * Bleed is routed through the player's damage report, so it feeds omnivamp —
#     Gorge or Rend running alongside a bleed heals you off the bleed itself.
class_name SkillData
extends Resource

enum Kind { OFFENSIVE, BUFF, MOVEMENT }

@export var skill_name: String = ""
@export var description: String = ""
@export var flavor: String = ""
@export var kind: Kind = Kind.OFFENSIVE
@export var cooldown: float = 3.0

# Years burned off the countdown when this skill fires. A normal attack costs 1.
# Zero means the skill is free: reserved for skills the player has no alternative
# to, like the movement that replaces walking once the legs are gone.
@export var year_cost: float = 0.0

# --- Offensive component ---
@export var aoe_damage: float = 0.0
@export var aoe_radius: float = 30.0
@export var aoe_color: Color = Color("4ecdc4")
@export var is_directional: bool = true # true = aimed at mouse, false = 360 around player

# --- Buff component ---
@export var buff_duration: float = 0.0
@export var buff_damage_mult: float = 1.0
@export var buff_damage_taken_mult: float = 1.0
@export var buff_omnivamp: float = 0.0 # Fraction of damage dealt returned as health
@export var buff_contact_retaliation: float = 0.0 # Damage to enemies touching the player
@export var buff_attack_cooldown_mult: float = 1.0
@export var buff_pulse_damage: float = 0.0
@export var buff_pulse_radius: float = 0.0
@export var buff_pulse_interval: float = 0.0
# Lights up every enemy that is about to hurt you (Instinct). Information the head
# used to supply, arriving as a reflex instead of a readout.
@export var buff_danger_sense: bool = false

# --- Impulse component ---
@export var impulse_speed: float = 0.0
@export var impulse_upward_bias: float = 0.0 # Extra upward velocity added to the impulse
# When true the impulse fires *away* from the cursor while the attack still lands
# toward it — a back-step strike. When false the impulse follows the aim.
@export var impulse_reverse: bool = false

# --- Status component (left on the enemies this skill touches) ---
@export var status_bleed_dps: float = 0.0
@export var status_bleed_time: float = 0.0
@export var status_mire_mult: float = 1.0   # below 1.0 = slower
@export var status_mire_time: float = 0.0
@export var status_reel_mult: float = 1.0   # above 1.0 = takes more damage
@export var status_reel_time: float = 0.0
# Lets a skill with no damage component still land its statuses, on everything
# within this radius of the player. 0 means "only what the attack actually hit".
@export var status_radius: float = 0.0

# Unlock conditions: trait_name -> Array[int] of size 2: [min_stage, max_stage].
# All conditions must be met simultaneously.
@export var unlock_conditions: Dictionary = {}


func has_status() -> bool:
	return (
		(status_bleed_dps > 0.0 and status_bleed_time > 0.0)
		or (status_mire_mult < 1.0 and status_mire_time > 0.0)
		or (status_reel_mult > 1.0 and status_reel_time > 0.0)
	)


func apply_status_to(enemy: Node) -> void:
	"""Put this skill's statuses on one enemy. Safe to call on anything — a node that
	is not a BaseEnemy simply has none of these methods."""
	if status_bleed_dps > 0.0 and status_bleed_time > 0.0 and enemy.has_method("apply_bleed"):
		enemy.call("apply_bleed", status_bleed_dps, status_bleed_time)
	if status_mire_mult < 1.0 and status_mire_time > 0.0 and enemy.has_method("apply_mire"):
		enemy.call("apply_mire", status_mire_mult, status_mire_time)
	if status_reel_mult > 1.0 and status_reel_time > 0.0 and enemy.has_method("apply_reeling"):
		enemy.call("apply_reeling", status_reel_mult, status_reel_time)


func is_unlocked(trait_states: Dictionary) -> bool:
	if unlock_conditions.is_empty():
		return false
	for trait_name: String in unlock_conditions:
		if not trait_states.has(trait_name):
			return false
		var stage: int = trait_states[trait_name] as int
		var bounds: Array = unlock_conditions[trait_name] as Array
		if bounds.size() < 2:
			return false
		var min_stage: int = bounds[0] as int
		var max_stage: int = bounds[1] as int
		if stage < min_stage or stage > max_stage:
			return false
	return true


func is_multi_trait() -> bool:
	return unlock_conditions.size() > 1


func get_trait_tags() -> Array[String]:
	var tags: Array[String] = []
	for trait_name: String in unlock_conditions:
		tags.append(trait_name)
	return tags


func get_cost_label() -> String:
	if year_cost <= 0.0:
		return "free"
	return "%d yr" % int(round(year_cost))


func get_kind_label() -> String:
	"""What this skill actually does, built from its components rather than from the
	single `kind` tag. Most skills carry more than one now, and labelling a dash that
	bleeds and slows as merely "MOVE" undersold the whole kit."""
	var parts: PackedStringArray = PackedStringArray()
	if aoe_damage > 0.0:
		parts.append("ATK")
	if impulse_speed > 0.0:
		parts.append("MOVE")
	if _has_self_buff():
		parts.append("BUFF")
	if has_status():
		parts.append("HEX")

	if parts.is_empty():
		# Fall back to the declared kind for anything that carries no component at all.
		match kind:
			Kind.BUFF:
				return "BUFF"
			Kind.MOVEMENT:
				return "MOVE"
			_:
				return "ATK"

	# Two tags is all the HUD's slot has room for; the first two are the ones that
	# describe how the skill is used rather than what it leaves behind.
	if parts.size() > 2:
		parts = PackedStringArray([parts[0], parts[1]])
	return "+".join(parts)


func _has_self_buff() -> bool:
	"""True when the skill grants a self-buff worth naming.

	A sub-second damage-taken change is the i-frame window on a dash, not a buff in
	its own right, so it is deliberately not counted — otherwise every movement skill
	would advertise itself as a buff."""
	if buff_duration <= 0.0:
		return false
	if buff_damage_mult != 1.0 or buff_omnivamp > 0.0 or buff_contact_retaliation > 0.0:
		return true
	if buff_attack_cooldown_mult != 1.0 or buff_pulse_damage > 0.0 or buff_danger_sense:
		return true
	return buff_damage_taken_mult != 1.0 and buff_duration >= 1.0


func get_requirement_text() -> String:
	"""Human readable unlock requirement, e.g. 'Arms lost, Legs intact-partial'."""
	var parts: PackedStringArray = PackedStringArray()
	for trait_name: String in unlock_conditions:
		var bounds: Array = unlock_conditions[trait_name] as Array
		if bounds.size() < 2:
			continue
		# Evolved traits ride in this dictionary as pseudo-traits whose stage 1 means
		# "grown". Running them through the base-trait stage names would print
		# "Wings partial", which is nonsense — they have no stages.
		if not TraitManager.ALL_TRAITS.has(trait_name):
			parts.append("%s grown" % trait_name.capitalize())
			continue
		var lo: int = bounds[0] as int
		var hi: int = bounds[1] as int
		var stage_text: String = ""
		if lo == hi:
			stage_text = TraitManager.STAGE_NAMES[lo].to_lower()
		else:
			stage_text = "%s-%s" % [
				TraitManager.STAGE_NAMES[lo].to_lower(),
				TraitManager.STAGE_NAMES[hi].to_lower(),
			]
		parts.append("%s %s" % [trait_name.capitalize(), stage_text])
	return ", ".join(parts)
