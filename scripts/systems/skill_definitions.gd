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
#   Head   full loss buff -> perception, not readout -> Hindbrain
#
# Plus multi-trait skills, which read a *combination* of capability rather than a
# single loss, and skills granted by the evolved traits that can grow in over a
# lost slot. Add new skills by adding entries to get_all_skills().
#
# Evolved traits appear in the unlock dictionary as pseudo-traits with stage
# 0 = dormant, 1 = grown (AbilityManager merges them in). So {"wings": [1, 1]}
# means "unlocked once wings have grown". Gills are deliberately skill-less: their
# payoff is lifting the lungs' swing penalty outright, and the rest of them waits
# on water terrain (ideate 3.3).
#
# STATUSES — why no skill here does only one thing
# Every skill carries at least two of {damage, self-buff, movement, status}. A kit
# where each entry is purely an attack, purely a dash, or purely a buff gives the
# player nothing to combine; the interesting decision is which skill sets up which.
# The three statuses are the connective tissue, and they are shared by design:
#
#   BLEED   damage over time, routed through the player's damage report — so it
#           feeds omnivamp. Gorge, Rend and Apex Instinct all heal off a bleed
#           somebody else applied.
#   MIRE    a slow. Buys the spacing that the telegraph-based enemies punish you
#           for not having.
#   REELING raises ALL incoming damage on that enemy. Anything that applies it is a
#           setup, never a finisher — statuses land after the applying skill's own
#           damage, so a skill can never amplify its own hit.
#
# The intended shape is: open with a REELING skill, spend the window on your
# heaviest hit, and keep a BLEED running underneath if you have any omnivamp.
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
	gorge.description = "For 6s, 45% of damage dealt returns as health — and everything nearby starts bleeding."
	gorge.flavor = "Nothing digests any more. It feeds on the blow itself."
	gorge.kind = SkillData.Kind.BUFF
	gorge.cooldown = 14.0
	gorge.year_cost = 8.0
	gorge.aoe_color = Color("2ecc71") # Green
	gorge.is_directional = false
	gorge.aoe_radius = 34.0
	gorge.buff_duration = 6.0
	gorge.buff_omnivamp = 0.45
	# The bleed it opens with feeds its own omnivamp — the skill heals you off a
	# wound it inflicted, which is exactly what a gut that cannot digest would do.
	gorge.status_bleed_dps = 5.0
	gorge.status_bleed_time = 6.0
	gorge.status_radius = 60.0
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
	# Whatever closes on you gets caught on the raw flesh and comes away slower.
	thornskin.status_mire_mult = 0.6
	thornskin.status_mire_time = 3.0
	thornskin.status_radius = 46.0
	thornskin.unlock_conditions = {"skin": [LOST, LOST]}
	skills.append(thornskin)

	# --------------------------------------------------------------- Arms ----
	# PLANNING1 gives arms a damage multiplier at full loss. The shoulders drive
	# everything now, so the hits that remain hit far harder.
	var surge: SkillData = SkillData.new()
	surge.skill_name = "Adrenal Surge"
	surge.description = "Throw your whole weight outward, then deal double damage for 5s."
	surge.flavor = "No hands to aim with. Only weight, and the will to throw it."
	surge.kind = SkillData.Kind.BUFF
	surge.cooldown = 15.0
	surge.year_cost = 10.0
	surge.aoe_color = Color("e74c3c") # Red
	surge.is_directional = false
	# The surge itself is a shove, so casting it also buys you space rather than
	# leaving you standing still in a crowd for the whole animation.
	surge.aoe_damage = 20.0
	surge.aoe_radius = 40.0
	surge.buff_duration = 5.0
	surge.buff_damage_mult = 2.0
	surge.unlock_conditions = {"arms": [LOST, LOST]}
	skills.append(surge)

	# --------------------------------------------------------------- Eyes ----
	# Vibration sense. Blind, but the ground reports back: a pulse every 0.7s.
	var echo: SkillData = SkillData.new()
	echo.skill_name = "Echo Sense"
	echo.description = "For 6s, pulse every 0.7s for damage in a wide radius. The first pulse finds every soft spot."
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
	# Vibration sense reads structure, not just position: everything it finds is
	# briefly easier to hurt. The widest reeling application in the game, which makes
	# blindness the best opener for somebody else's heavy hit.
	echo.status_reel_mult = 1.35
	echo.status_reel_time = 2.5
	echo.status_radius = 72.0
	echo.unlock_conditions = {"eyes": [LOST, LOST]}
	skills.append(echo)

	# -------------------------------------------------------------- Lungs ----
	# No breath left to budget, so there is nothing left to pace. Free burst attacks.
	var wind: SkillData = SkillData.new()
	wind.skill_name = "Second Wind"
	wind.description = "Surge forward on the last of your breath, then swing at quadruple speed for 5s."
	wind.flavor = "It has stopped budgeting its breath. There is none left to budget."
	wind.kind = SkillData.Kind.BUFF
	wind.cooldown = 14.0
	wind.year_cost = 8.0
	wind.aoe_color = Color("1abc9c") # Teal
	wind.is_directional = false
	wind.aoe_radius = 28.0
	wind.buff_duration = 5.0
	wind.buff_attack_cooldown_mult = 0.25
	# The breath goes somewhere. Carrying you into range is what makes the swing
	# speed usable instead of something you stand still and waste.
	wind.impulse_speed = 240.0
	wind.impulse_upward_bias = 110.0
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
	# You land on them teeth first. The bleed is what turns free movement into
	# pressure, so the legs' replacement is not purely defensive.
	pounce.status_bleed_dps = 6.0
	pounce.status_bleed_time = 4.0
	pounce.status_radius = 32.0
	pounce.unlock_conditions = {"legs": [LOST, LOST]}
	skills.append(pounce)

	# --------------------------------------------------------------- Head ----
	# The last gap in PLANNING1's trait->skill map. Losing the head has always taken
	# the HUD's numbers away; this is what the body grows in their place. It restores
	# no information at all — it replaces knowing with noticing. Anything committed to
	# hurting you lights up, and you flinch better from what still lands.
	# (ideate 1.4 called this "Instinct"; renamed because "Apex Instinct" already
	# exists as a multi-trait skill and two near-identical names in the same list is
	# a UI problem. "Hindbrain" also says the thing more exactly.)
	var instinct: SkillData = SkillData.new()
	instinct.skill_name = "Hindbrain"
	instinct.description = "For 8s, anything about to hit you lights up, and you take 25% less damage."
	instinct.flavor = "It cannot read the fight any more. It can still feel the moment before."
	instinct.kind = SkillData.Kind.BUFF
	instinct.cooldown = 15.0
	instinct.year_cost = 8.0
	instinct.aoe_color = Color("f7dc6f") # Pale warning yellow
	instinct.is_directional = false
	instinct.aoe_radius = 38.0
	instinct.buff_duration = 8.0
	instinct.buff_damage_taken_mult = 0.75
	instinct.buff_danger_sense = true
	# Noticing where something is about to come from is also noticing where it is
	# open. Pairs with itself: the highlight tells you who to spend the window on.
	instinct.status_reel_mult = 1.25
	instinct.status_reel_time = 4.0
	instinct.status_radius = 80.0
	instinct.unlock_conditions = {"head": [LOST, LOST]}
	skills.append(instinct)

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
	# A kick that lands takes the legs out from under them.
	kick.status_mire_mult = 0.5
	kick.status_mire_time = 2.5
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
	# Opens every body around you at once, and its own omnivamp drinks from them.
	apex.status_bleed_dps = 8.0
	apex.status_bleed_time = 7.0
	apex.status_radius = 60.0
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
	# A flurry that wild leaves everything it clipped rattled and open.
	fury.status_reel_mult = 1.4
	fury.status_reel_time = 3.0
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
	# Scrabbling away throws up enough debris to foul whatever was chasing you, so
	# the escape also buys the spacing that makes it worth escaping to.
	scramble.status_mire_mult = 0.7
	scramble.status_mire_time = 1.5
	scramble.status_radius = 36.0
	scramble.unlock_conditions = {"legs": [PARTIAL, PARTIAL]}
	skills.append(scramble)

	# Wings grown: a long horizontal air-dash. The signature wing traversal tool.
	var wing_dash: SkillData = SkillData.new()
	wing_dash.skill_name = "Wing Dash"
	wing_dash.description = "A long dash toward the cursor, cutting anything you pass through. Untouchable during it."
	wing_dash.flavor = "The arms are gone. What is left of them carries you further than they ever did."
	wing_dash.kind = SkillData.Kind.MOVEMENT
	wing_dash.cooldown = 2.5
	wing_dash.year_cost = 0.0 # Free — with the arms gone this is core mobility, like Pounce.
	wing_dash.aoe_color = Color("aed6f1") # Pale sky
	wing_dash.is_directional = true
	# Passing through something at that speed costs it something. Keeps the free
	# core-mobility skill from being a pure disengage button.
	wing_dash.aoe_damage = 22.0
	wing_dash.aoe_radius = 26.0
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
	updraft.description = "Launch straight up on a burst of air, throwing everything around you off its feet."
	updraft.flavor = "It catches a column of rising air the way it once caught a handhold."
	updraft.kind = SkillData.Kind.MOVEMENT
	updraft.cooldown = 5.0
	updraft.year_cost = 1.0
	updraft.aoe_color = Color("d2f0f5")
	updraft.is_directional = false
	# The same column of air that lifts you scatters what was closing on you — the
	# escape and the reset are one action instead of two.
	updraft.aoe_damage = 18.0
	updraft.aoe_radius = 42.0
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
	# Arriving that hard leaves them open — this is the game's cleanest opener, since
	# it closes the distance and sets up the hit in the same button.
	lunge.status_reel_mult = 1.4
	lunge.status_reel_time = 3.0
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
	# You leave the wound behind you as you go. Weak arms cannot finish anything, so
	# they open it and let the bleed do the rest.
	backstep.status_bleed_dps = 7.0
	backstep.status_bleed_time = 4.0
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
	# Everything under it gets pinned. The slow is what lets you convert the dive
	# into a follow-up instead of just trading a big hit and leaving.
	slam.status_mire_mult = 0.45
	slam.status_mire_time = 3.0
	slam.unlock_conditions = {"wings": [1, 1]}
	skills.append(slam)

	# ------------------------------------------- Evolved trait skills ----
	# Each of these needs its evolved trait grown, so they are the deepest branch in
	# the game: a specific combination of losses, accepted, permanently.

	# Claws: no reach at all, so the verb is committing to being inside the enemy's
	# space. Tearing rather than striking, and a torn thing feeds you for a moment.
	var rend: SkillData = SkillData.new()
	rend.skill_name = "Rend"
	rend.description = "Tear everything at arm's length apart. Heavy, close, and the wound feeds you for 3s."
	rend.flavor = "Not a blow. A grip that does not let go until something comes away."
	rend.kind = SkillData.Kind.OFFENSIVE
	rend.cooldown = 5.0
	rend.year_cost = 2.0
	rend.aoe_damage = 58.0
	rend.aoe_radius = 26.0 # Deliberately tight — claws trade reach for everything else.
	rend.aoe_color = Color("e8dcc8")
	rend.is_directional = true
	rend.buff_duration = 3.0
	rend.buff_omnivamp = 0.35
	# The signature combo in the game: the heaviest bleed, running underneath its own
	# omnivamp window, so Rend heals you off the wound Rend opened.
	rend.status_bleed_dps = 12.0
	rend.status_bleed_time = 5.0
	rend.unlock_conditions = {"claws": [1, 1]}
	skills.append(rend)

	# Tail: a full 360° sweep. The one skill that does not care where the cursor is,
	# because a tail does not aim — it clears the space you are standing in.
	var whip: SkillData = SkillData.new()
	whip.skill_name = "Tail Whip"
	whip.description = "Sweep the tail in a full circle, throwing back everything around you."
	whip.flavor = "It does not aim it. It simply takes back the ground it is standing on."
	whip.kind = SkillData.Kind.OFFENSIVE
	whip.cooldown = 4.0
	whip.year_cost = 1.0
	whip.aoe_damage = 30.0
	whip.aoe_radius = 48.0 # Wide, but weak per target — this is spacing, not damage.
	whip.aoe_color = Color("bb8fce")
	whip.is_directional = false
	# Spacing, not damage — so the slow is the actual payload and the damage is the
	# excuse for it.
	whip.status_mire_mult = 0.55
	whip.status_mire_time = 3.0
	whip.unlock_conditions = {"tail": [1, 1]}
	skills.append(whip)

	# Plates: too heavy to dodge with, so the answer to a crowd is to go through it.
	# No i-frames — you are armored, not absent, which is the whole character of them.
	var ram: SkillData = SkillData.new()
	ram.skill_name = "Ram"
	ram.description = "Drop your shoulder and charge, bowling over anything in the way."
	ram.flavor = "Nothing about it is fast. Nothing about it has to be."
	ram.kind = SkillData.Kind.OFFENSIVE
	ram.cooldown = 5.0
	ram.year_cost = 2.0
	ram.aoe_damage = 46.0
	ram.aoe_radius = 32.0
	ram.aoe_color = Color("a1887f")
	ram.is_directional = true
	ram.impulse_speed = 380.0
	ram.impulse_upward_bias = 20.0
	ram.buff_duration = 0.4
	ram.buff_damage_taken_mult = 0.35 # Heavily armored through it, not untouchable.
	# Being hit by something that heavy rattles whatever it caught. The strongest
	# reeling in the game, on the skill that has to walk into the crowd to use it.
	ram.status_reel_mult = 1.5
	ram.status_reel_time = 3.0
	ram.unlock_conditions = {"plates": [1, 1]}
	skills.append(ram)

	# Hide: it has grown in thick and plated. It can pull in tight and weather
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
	# Anything grinding against the hide comes away worse for it, and slower.
	curl.status_mire_mult = 0.5
	curl.status_mire_time = 3.0
	curl.status_radius = 40.0
	curl.unlock_conditions = {"hide": [1, 1]}
	skills.append(curl)

	return skills
