# skill_definitions.gd
# Static factory that creates the starter skill set.
# Add new skills by adding entries to get_all_skills().
class_name SkillDefinitions
extends RefCounted


static func get_all_skills() -> Array[SkillData]:
	var skills: Array[SkillData] = []

	# Devastating Kick: arms extinct + legs still good
	var kick: SkillData = SkillData.new()
	kick.skill_name = "Devastating Kick"
	kick.description = "A powerful frontal kick. Unlocked when arms are extinct but legs remain strong."
	kick.cooldown = 2.5
	kick.damage = 60.0
	kick.aoe_radius = 24.0
	kick.aoe_color = Color("e74c3c") # Red
	kick.is_directional = true
	kick.unlock_conditions = {"arms": [5, 5], "legs": [0, 2]}
	skills.append(kick)

	# Primal Roar: speech and head still good
	var roar: SkillData = SkillData.new()
	roar.skill_name = "Primal Roar"
	roar.description = "A 360° shockwave that pushes all enemies away. Unlocked with intact speech and head."
	roar.cooldown = 5.0
	roar.damage = 20.0
	roar.aoe_radius = 50.0
	roar.aoe_color = Color("f39c12") # Orange
	roar.is_directional = false
	roar.unlock_conditions = {"speech": [0, 2], "head": [0, 2]}
	skills.append(roar)

	# Blind Fury: eyes degraded + arms still partially working
	var fury: SkillData = SkillData.new()
	fury.skill_name = "Blind Fury"
	fury.description = "Rapid multi-hit in a wide arc. Unlocked when vision is impaired but arms still function."
	fury.cooldown = 4.0
	fury.damage = 35.0
	fury.aoe_radius = 32.0
	fury.aoe_color = Color("9b59b6") # Purple
	fury.is_directional = true
	fury.unlock_conditions = {"eyes": [4, 5], "arms": [0, 3]}
	skills.append(fury)

	# Iron Gut: gut degraded + legs still partially working
	var slam: SkillData = SkillData.new()
	slam.skill_name = "Iron Gut"
	slam.description = "AoE ground slam that stuns nearby enemies. Unlocked with degraded gut and working legs."
	slam.cooldown = 6.0
	slam.damage = 45.0
	slam.aoe_radius = 40.0
	slam.aoe_color = Color("2ecc71") # Green
	slam.is_directional = false
	slam.unlock_conditions = {"gut": [3, 5], "legs": [0, 3]}
	skills.append(slam)

	return skills
