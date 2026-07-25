# skill_definitions.gd
# Static factory that creates the skill set.
#
# Every skill here is the buff PLANNING1 section 6 grants at full loss of a trait,
# built from that trait's core idea:
#
#   Arms   full loss buff -> damage multiplier      -> Adrenal Surge
#   Legs   full loss buff -> alternative movement   -> Pounce
#   Gut    full loss buff -> feeds on the strike    -> Gorge (omnivamp)
#   Lungs  full loss buff -> free burst attacks     -> Second Wind
#   Eyes   full loss buff -> vibration sense        -> Echo Sense
#   Skin   full loss buff -> raw body retaliates    -> Thornskin
#   Head   full loss buff -> undecided in PLANNING1 -> no skill yet
#
# Plus multi-trait skills, which read a *combination* of capability rather than a
# single loss, and skills granted by the evolved traits (Wings, Hide) that can
# grow in over a lost trait. Add new skills by adding entries to get_all_skills().
#
# Evolved traits appear in the unlock dictionary as pseudo-traits with stage
# 0 = dormant, 1 = grown (AbilityManager merges them in). So {"wings": [1, 1]}
# means "unlocked once wings have grown".
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
	gorge.year_cost = 8.0
	gorge.aoe_color = Color("2ecc71") # Green
	gorge.is_directional = false
	gorge.aoe_radius = 34.0
	gorge.buff_duration = 6.0
	gorge.buff_omnivamp = 0.45
	gorge.unlock_conditions = {"gut": [LOST, LOST]}
	skills.append(gorge)

	# --------------------------------------------------------------- Skin ----
	# The skin is gone; the raw body underneath answers contact with pain of its
	# own. Brief toughening plus retaliation against anything that touches you.
	var thornskin: SkillData = SkillData.new()
	thornskin.skill_name = "Thornskin"
	thornskin.description = "For 8s, take 45% less damage and burn anything that touches you."
	thornskin.flavor = "Nothing left to protect it, so the raw flesh answers every touch."
	thornskin.kind = SkillData.Kind.BUFF
	thornskin.cooldown = 16.0
	thornskin.year_cost = 8.0
	thornskin.aoe_color = Color("f39c12") # Orange
	thornskin.is_directional = false
	thornskin.aoe_radius = 40.0
	thornskin.buff_duration = 8.0
	thornskin.buff_damage_taken_mult = 0.55
	thornskin.buff_contact_retaliation = 16.0
	thornskin.unlock_conditions = {"skin": [LOST, LOST]}
	skills.append(thornskin)

	# --------------------------------------------------------------- Arms ----
	# PLANNING1 gives arms a damage multiplier at full loss. The shoulders drive
	# everything now, so the hits that remain hit far harder.
	var surge: SkillData = SkillData.new()
	surge.skill_name = "Adrenal Surge"
	surge.description = "For 5s, everything you do deals double damage."
	surge.flavor = "No hands to aim with. Only weight, and the will to throw it."
	surge.kind = SkillData.Kind.BUFF
	surge.cooldown = 15.0
	surge.year_cost = 10.0
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
	echo.year_cost = 8.0
	echo.aoe_color = Color("9b59b6") # Purple
	echo.is_directional = false
	echo.aoe_radius = 30.0
	echo.buff_duration = 6.0
	echo.buff_pulse_damage = 12.0
	echo.buff_pulse_radius = 72.0
	echo.buff_pulse_interval = 0.7
	echo.unlock_conditions = {"eyes": [LOST, LOST]}
	skills.append(echo)

	# -------------------------------------------------------------- Lungs ----
	# No breath left to budget, so there is nothing left to pace. Free burst attacks.
	var wind: SkillData = SkillData.new()
	wind.skill_name = "Second Wind"
	wind.description = "For 5s, attack cooldown drops to a quarter."
	wind.flavor = "It has stopped budgeting its breath. There is none left to budget."
	wind.kind = SkillData.Kind.BUFF
	wind.cooldown = 14.0
	wind.year_cost = 8.0
	wind.aoe_color = Color("1abc9c") # Teal
	wind.is_directional = false
	wind.aoe_radius = 28.0
	wind.buff_duration = 5.0
	wind.buff_attack_cooldown_mult = 0.25
	wind.unlock_conditions = {"lungs": [LOST, LOST]}
	skills.append(wind)

	# --------------------------------------------------------------- Legs ----
	# Alternative movement. Walking is gone; what is left is a lunge that hurts.
	var pounce: SkillData = SkillData.new()
	pounce.skill_name = "Pounce"
	pounce.description = "Leap toward the cursor. Briefly untouchable, and it hurts on contact."
	pounce.flavor = "It no longer walks anywhere. It arrives."
	pounce.kind = SkillData.Kind.MOVEMENT
	pounce.cooldown = 3.0
	pounce.year_cost = 0.0
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
	kick.year_cost = 1.0
	kick.aoe_damage = 60.0
	kick.aoe_radius = 32.0
	kick.aoe_color = Color("e67e22") # Dark orange
	kick.is_directional = true
	kick.unlock_conditions = {"arms": [LOST, LOST], "legs": [INTACT, PARTIAL]}
	skills.append(kick)

	# No skin to protect it and no gut to feed it. The body simply takes.
	var apex: SkillData = SkillData.new()
	apex.skill_name = "Apex Instinct"
	apex.description = "For 7s: +50% damage, 35% less damage taken, and 30% omnivamp."
	apex.flavor = "Bare and starving at once. What remains is entirely appetite."
	apex.kind = SkillData.Kind.BUFF
	apex.cooldown = 24.0
	apex.year_cost = 15.0
	apex.aoe_color = Color("f1c40f") # Gold
	apex.is_directional = false
	apex.aoe_radius = 46.0
	apex.buff_duration = 7.0
	apex.buff_damage_mult = 1.5
	apex.buff_damage_taken_mult = 0.65
	apex.buff_omnivamp = 0.3
	apex.unlock_conditions = {"gut": [LOST, LOST], "skin": [LOST, LOST]}
	skills.append(apex)

	# Blind and half-crippled, but the arms still swing: a wide, frantic sweep.
	var fury: SkillData = SkillData.new()
	fury.skill_name = "Blind Fury"
	fury.description = "A wide arc sweep that hits everything in front of you."
	fury.flavor = "It cannot see what it is hitting. It hits anyway."
	fury.kind = SkillData.Kind.OFFENSIVE
	fury.cooldown = 4.0
	fury.year_cost = 2.0
	fury.aoe_damage = 38.0
	fury.aoe_radius = 44.0
	fury.aoe_color = Color("8e44ad") # Deep purple
	fury.is_directional = true
	fury.unlock_conditions = {"eyes": [PARTIAL, LOST], "arms": [INTACT, PARTIAL]}
	skills.append(fury)

	# ------------------------------------------------ Mobility skills ----
	# More movement expression per the design goal. Every skill fired mid-air also
	# refreshes the jump (player.gd), so these chain into and out of jumps.

	# The legs have started to fail, so clean running gives way to a scrambling
	# evasive lunge. A short i-frame dash — appears once the legs go partial, so it
	# is a mid-run mobility tool rather than something handed out at full health.
	var scramble: SkillData = SkillData.new()
	scramble.skill_name = "Scramble"
	scramble.description = "A quick evasive dash toward the cursor. Briefly untouchable."
	scramble.flavor = "Not grace. Just the oldest reflex there is: move."
	scramble.kind = SkillData.Kind.MOVEMENT
	scramble.cooldown = 4.0
	scramble.year_cost = 1.0
	scramble.aoe_color = Color("5dade2") # Light blue
	scramble.is_directional = true
	scramble.aoe_radius = 20.0
	scramble.impulse_speed = 300.0
	scramble.impulse_upward_bias = 20.0
	scramble.buff_duration = 0.25
	scramble.buff_damage_taken_mult = 0.0 # i-frames for the dash
	scramble.unlock_conditions = {"legs": [PARTIAL, PARTIAL]}
	skills.append(scramble)

	# Wings grown: a long horizontal air-dash. The signature wing traversal tool.
	var wing_dash: SkillData = SkillData.new()
	wing_dash.skill_name = "Wing Dash"
	wing_dash.description = "Beat your wings for a long dash toward the cursor. Untouchable during it."
	wing_dash.flavor = "The arms are gone. What is left of them carries you further than they ever did."
	wing_dash.kind = SkillData.Kind.MOVEMENT
	wing_dash.cooldown = 2.5
	wing_dash.year_cost = 0.0 # Free — with the arms gone this is core mobility, like Pounce.
	wing_dash.aoe_color = Color("aed6f1") # Pale sky
	wing_dash.is_directional = true
	wing_dash.aoe_radius = 24.0
	wing_dash.impulse_speed = 420.0
	wing_dash.impulse_upward_bias = 40.0
	wing_dash.buff_duration = 0.35
	wing_dash.buff_damage_taken_mult = 0.0
	wing_dash.unlock_conditions = {"wings": [1, 1]}
	skills.append(wing_dash)

	# Wings grown: a hard vertical launch, for reaching the high route or resetting
	# a fight from above. Pairs with the glide (hold jump after) to stay up there.
	var updraft: SkillData = SkillData.new()
	updraft.skill_name = "Updraft"
	updraft.description = "Launch straight up on a burst of air. Hold jump after to glide."
	updraft.flavor = "It catches a column of rising air the way it once caught a handhold."
	updraft.kind = SkillData.Kind.MOVEMENT
	updraft.cooldown = 5.0
	updraft.year_cost = 1.0
	updraft.aoe_color = Color("d2f0f5")
	updraft.is_directional = false
	updraft.aoe_radius = 26.0
	updraft.impulse_speed = 60.0
	updraft.impulse_upward_bias = 340.0 # Almost all of the push is upward.
	updraft.buff_duration = 0.3
	updraft.buff_damage_taken_mult = 0.0
	updraft.unlock_conditions = {"wings": [1, 1]}
	skills.append(updraft)

	# --------------------------------------- Attack + movement skills ----
	# Skills that move you AND hit — the engaging "commit to a strike" verbs. They
	# carry both an offensive AoE and an impulse, so they read as a dash-through, a
	# hit-and-retreat, a dive. Fired in mid-air they also refresh the jump.

	# Legs are failing, so clean spacing gives way to explosive committed lunges: a
	# forward dash that strikes on arrival, untouchable through it. Needs the arms
	# to still land the blow.
	var lunge: SkillData = SkillData.new()
	lunge.skill_name = "Lunge Strike"
	lunge.description = "Dash to the cursor and strike on arrival. Untouchable during the lunge."
	lunge.flavor = "No footwork left. Just the whole body, thrown, with teeth on the end of it."
	lunge.kind = SkillData.Kind.OFFENSIVE
	lunge.cooldown = 5.0
	lunge.year_cost = 2.0
	lunge.aoe_damage = 42.0
	lunge.aoe_radius = 30.0
	lunge.aoe_color = Color("f5b041") # Amber
	lunge.is_directional = true
	lunge.impulse_speed = 360.0
	lunge.impulse_upward_bias = 40.0
	lunge.buff_duration = 0.3
	lunge.buff_damage_taken_mult = 0.0 # i-frames for the lunge
	lunge.unlock_conditions = {"arms": [INTACT, PARTIAL], "legs": [PARTIAL, LOST]}
	skills.append(lunge)

	# The arms have weakened, so trade reach for safety: strike toward the cursor,
	# then leap the opposite way. The classic hit-and-run.
	var backstep: SkillData = SkillData.new()
	backstep.skill_name = "Backstep Slash"
	backstep.description = "Strike toward the cursor, then leap back out of reach. Untouchable on the retreat."
	backstep.flavor = "It can still bite. It just can no longer afford to stay."
	backstep.kind = SkillData.Kind.OFFENSIVE
	backstep.cooldown = 5.0
	backstep.year_cost = 2.0
	backstep.aoe_damage = 34.0
	backstep.aoe_radius = 30.0
	backstep.aoe_color = Color("c39bd3") # Soft violet
	backstep.is_directional = true
	backstep.impulse_speed = 300.0
	backstep.impulse_upward_bias = 30.0
	backstep.impulse_reverse = true # attack forward, leap backward
	backstep.buff_duration = 0.3
	backstep.buff_damage_taken_mult = 0.0
	backstep.unlock_conditions = {"arms": [PARTIAL, PARTIAL]}
	skills.append(backstep)

	# Wings grown: a diving body-slam toward the cursor. Heavy, and best entered from
	# a jump or glide, turning height into damage.
	var slam: SkillData = SkillData.new()
	slam.skill_name = "Wing Slam"
	slam.description = "Dive toward the cursor and slam down, hitting everything you land on."
	slam.flavor = "It folds the wings and falls on purpose, the way it once let go of a branch."
	slam.kind = SkillData.Kind.OFFENSIVE
	slam.cooldown = 4.0
	slam.year_cost = 1.0
	slam.aoe_damage = 52.0
	slam.aoe_radius = 36.0
	slam.aoe_color = Color("85c1e9") # Sky
	slam.is_directional = true
	slam.impulse_speed = 400.0
	slam.impulse_upward_bias = -50.0 # negative = extra downward drive for the dive
	slam.buff_duration = 0.3
	slam.buff_damage_taken_mult = 0.0
	slam.unlock_conditions = {"wings": [1, 1]}
	skills.append(slam)

	# ---------------------------------------------- Evolved: Hide ----
	# The hide has grown in thick and plated. It can pull in tight and weather
	# almost anything for a moment, punishing whatever is pressed against it.
	var curl: SkillData = SkillData.new()
	curl.skill_name = "Curl"
	curl.description = "For 4s, pull into the hide: take almost no damage and grind anything touching you."
	curl.flavor = "Older armor than any weapon. It simply closes, and waits."
	curl.kind = SkillData.Kind.BUFF
	curl.cooldown = 18.0
	curl.year_cost = 6.0
	curl.aoe_color = Color("7f8c8d") # Slate grey
	curl.is_directional = false
	curl.aoe_radius = 34.0
	curl.buff_duration = 4.0
	curl.buff_damage_taken_mult = 0.15
	curl.buff_contact_retaliation = 22.0
	curl.unlock_conditions = {"hide": [1, 1]}
	skills.append(curl)

	return skills
