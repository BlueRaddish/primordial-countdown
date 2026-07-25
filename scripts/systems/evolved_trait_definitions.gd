# evolved_trait_definitions.gd
# Static factory for the evolved traits — the hidden "grow it back" options.
#
# Each one is revealed by a specific combination of losses and, if accepted, takes
# over the role of a trait that is already gone. They are the counterweight to pure
# devolution: the run only strips you down, but a few of those stripped states open
# an older shape underneath. Add one by appending to get_all().
class_name EvolvedTraitDefinitions
extends RefCounted

const INTACT: int = 0
const PARTIAL: int = 1
const LOST: int = 2


static func get_all() -> Array[EvolvedTraitData]:
	var out: Array[EvolvedTraitData] = []

	# Wings — the arms are gone, and what remains of the forelimb reopens as a wing.
	# Trades the melee the arms used to give for flight: an extra flap, a glide
	# (hold jump while falling), and the wing mobility skills.
	var wings: EvolvedTraitData = EvolvedTraitData.new()
	wings.id = "wings"
	wings.display_name = "Wings"
	wings.description = "Grow wings over the dead arms: an extra mid-air flap, a glide, and wing dashes."
	wings.flavor = "The forelimb remembers an older use than holding. It opens, and catches the air."
	wings.color = Color("aed6f1")
	wings.replaces_trait = "arms"
	wings.unlock_conditions = {"arms": [LOST, LOST]}
	out.append(wings)

	# Hide — soft tissue has failed on two fronts (skin and lungs both gone), so the
	# body plates over. Heavy passive armor, plus the Curl skill to weather a burst.
	var hide: EvolvedTraitData = EvolvedTraitData.new()
	hide.id = "hide"
	hide.display_name = "Hide"
	hide.description = "Plate over the raw body with a thick hide: heavy, permanent damage reduction."
	hide.flavor = "When the soft parts give out, something older and harder grows in their place."
	hide.color = Color("7f8c8d")
	hide.replaces_trait = "skin"
	hide.hide_damage_mult = 0.6 # 40% flat reduction, far past what intact skin gave.
	hide.unlock_conditions = {"skin": [LOST, LOST], "lungs": [LOST, LOST]}
	out.append(hide)

	return out
