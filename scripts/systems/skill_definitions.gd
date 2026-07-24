# skill_definitions.gd
# Static factory that creates the skill set.
#
# Every skill here is the buff PLANNING1 section 6 grants at full loss of a trait,
# built from that trait's core idea:
#
#   Arms   full loss buff -> damage multiplier      -> Adrenal Surge
#   Legs   full loss buff -> alternative movement   -> Pounce
#   Gut    full loss buff -> feeds on the strike    -> Gorge (omnivamp)
#   Throat full loss buff -> free burst attacks     -> Second Wind
#   Eyes   full loss buff -> vibration sense        -> Echo Sense
#   Speech full loss buff -> permanent aura         -> Threat Aura
#   Head   full loss buff -> undecided in PLANNING1 -> no skill yet
#
# Plus multi-trait skills, which read a *combination* of capability rather than a
# single loss. Add new skills by adding entries to get_all_skills().
class_name SkillDefinitions
extends RefCounted

# Stage shorthand, matching TraitManager.
const INTACT: int = 0
const PARTIAL: int = 1
const LOST: int = 2


static func get_all_skills() -> Array[SkillData]:
	var skills: Array[SkillData] = []

	# ---------------------------------------------------------------- Gut ----
	# The gut can no longer draw nourishment from food, so it draws it from the
	# strike instead. Temporary omnivamp: the loss of regen is softened, not undone.
	var gorge: SkillData = SkillData.new()
	gorge.skill_name = "Gorge"
	gorge.description = "For 6s, 45% of all damage you deal returns to you as health."
	gorge.flavor = "Nothing digests any more. It feeds on the blow itself."
	gorge.kind = SkillData.Kind.BUFF
	gorge.cooldown = 14.0
	gorge.aoe_color = Color("2ecc71") # Green
	gorge.is_directional = false
	gorge.aoe_radius = 34.0
	gorge.buff_duration = 6.0
	gorge.buff_omnivamp = 0.45
	gorge.unlock_conditions = {"gut": [LOST, LOST]}
	skills.append(gorge)

	# ------------------------------------------------------------- Speech ----
	# No voice left to warn or threaten with, so the body radiates threat instead.
	# Damage reduction plus retaliation against anything that touches you.
	var aura: SkillData = SkillData.new()
	aura.skill_name = "Threat Aura"
	aura.description = "For 8s, take 45% less damage and burn anything that touches you."
	aura.flavor = "It cannot cry out. It simply becomes something you do not approach."
	aura.kind = SkillData.Kind.BUFF
	aura.cooldown = 16.0
	aura.aoe_color = Color("f39c12") # Orange
	aura.is_directional = false
	aura.aoe_radius = 40.0
	aura.buff_duration = 8.0
	aura.buff_damage_taken_mult = 0.55
	aura.buff_contact_retaliation = 16.0
	aura.unlock_conditions = {"speech": [LOST, LOST]}
	skills.append(aura)

	# --------------------------------------------------------------- Arms ----
	# PLANNING1 gives arms a damage multiplier at full loss. The shoulders drive
	# everything now, so the hits that remain hit far harder.
	var surge: SkillData = SkillData.new()
	surge.skill_name = "Adrenal Surge"
	surge.description = "For 5s, everything you do deals double damage."
	surge.flavor = "No hands to aim with. Only weight, and the will to throw it."
	surge.kind = SkillData.Kind.BUFF
	surge.cooldown = 15.0
	surge.aoe_color = Color("e74c3c") # Red
	surge.is_directional = false
	surge.aoe_radius = 30.0
	surge.buff_duration = 5.0
	surge.buff_damage_mult = 2.0
	surge.unlock_conditions = {"arms": [LOST, LOST]}
	skills.append(surge)

	# --------------------------------------------------------------- Eyes ----
	# Vibration sense. Blind, but the ground reports back: a pulse every 0.7s.
	var echo: SkillData = SkillData.new()
	echo.skill_name = "Echo Sense"
	echo.description = "For 6s, pulse every 0.7s, damaging everything within a wide radius."
	echo.flavor = "It stopped looking. The floor tells it everything it needs."
	echo.kind = SkillData.Kind.BUFF
	echo.cooldown = 13.0
	echo.aoe_color = Color("9b59b6") # Purple
	echo.is_directional = false
	echo.aoe_radius = 30.0
	echo.buff_duration = 6.0
	echo.buff_pulse_damage = 12.0
	echo.buff_pulse_radius = 72.0
	echo.buff_pulse_interval = 0.7
	echo.unlock_conditions = {"eyes": [LOST, LOST]}
	skills.append(echo)

	# ------------------------------------------------------------- Throat ----
	# No stamina regulation left, so there is nothing left to pace. Free burst attacks.
	var wind: SkillData = SkillData.new()
	wind.skill_name = "Second Wind"
	wind.description = "For 5s, attack cooldown drops to a quarter."
	wind.flavor = "It has stopped budgeting its breath. There is none left to budget."
	wind.kind = SkillData.Kind.BUFF
	wind.cooldown = 14.0
	wind.aoe_color = Color("1abc9c") # Teal
	wind.is_directional = false
	wind.aoe_radius = 28.0
	wind.buff_duration = 5.0
	wind.buff_attack_cooldown_mult = 0.25
	wind.unlock_conditions = {"throat": [LOST, LOST]}
	skills.append(wind)

	# --------------------------------------------------------------- Legs ----
	# Alternative movement. Walking is gone; what is left is a lunge that hurts.
	var pounce: SkillData = SkillData.new()
	pounce.skill_name = "Pounce"
	pounce.description = "Leap toward the cursor. Briefly untouchable, and it hurts on contact."
	pounce.flavor = "It no longer walks anywhere. It arrives."
	pounce.kind = SkillData.Kind.MOVEMENT
	pounce.cooldown = 3.0
	pounce.aoe_color = Color("3498db") # Blue
	pounce.is_directional = true
	pounce.aoe_radius = 26.0
	pounce.impulse_speed = 320.0
	pounce.impulse_upward_bias = 70.0
	pounce.buff_duration = 0.45
	pounce.buff_damage_taken_mult = 0.0 # Untouchable for the leap
	pounce.buff_contact_retaliation = 30.0
	pounce.unlock_conditions = {"legs": [LOST, LOST]}
	skills.append(pounce)

	# ------------------------------------------------- Multi-trait skills ----
	# Arms are gone but the legs still work: the kick becomes the whole moveset.
	var kick: SkillData = SkillData.new()
	kick.skill_name = "Devastating Kick"
	kick.description = "A heavy frontal kick. Needs dead arms and legs that still carry weight."
	kick.flavor = "One capability collapses onto another and sharpens it."
	kick.kind = SkillData.Kind.OFFENSIVE
	kick.cooldown = 2.5
	kick.aoe_damage = 60.0
	kick.aoe_radius = 32.0
	kick.aoe_color = Color("e67e22") # Dark orange
	kick.is_directional = true
	kick.unlock_conditions = {"arms": [LOST, LOST], "legs": [INTACT, PARTIAL]}
	skills.append(kick)

	# Nothing left to say and nothing left to digest. The body simply takes.
	var apex: SkillData = SkillData.new()
	apex.skill_name = "Apex Instinct"
	apex.description = "For 7s: +50% damage, 35% less damage taken, and 30% omnivamp."
	apex.flavor = "Two silences at once. What remains is entirely appetite."
	apex.kind = SkillData.Kind.BUFF
	apex.cooldown = 24.0
	apex.aoe_color = Color("f1c40f") # Gold
	apex.is_directional = false
	apex.aoe_radius = 46.0
	apex.buff_duration = 7.0
	apex.buff_damage_mult = 1.5
	apex.buff_damage_taken_mult = 0.65
	apex.buff_omnivamp = 0.3
	apex.unlock_conditions = {"gut": [LOST, LOST], "speech": [LOST, LOST]}
	skills.append(apex)

	# Blind and half-crippled, but the arms still swing: a wide, frantic sweep.
	var fury: SkillData = SkillData.new()
	fury.skill_name = "Blind Fury"
	fury.description = "A wide arc sweep that hits everything in front of you."
	fury.flavor = "It cannot see what it is hitting. It hits anyway."
	fury.kind = SkillData.Kind.OFFENSIVE
	fury.cooldown = 4.0
	fury.aoe_damage = 38.0
	fury.aoe_radius = 44.0
	fury.aoe_color = Color("8e44ad") # Deep purple
	fury.is_directional = true
	fury.unlock_conditions = {"eyes": [PARTIAL, LOST], "arms": [INTACT, PARTIAL]}
	skills.append(fury)

	return skills
