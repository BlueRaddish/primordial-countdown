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

	# Wings — the arms are gone and what remains of the forelimb reopens as a wing,
	# but only while the breath (lungs) is still whole enough to power flight and the
	# legs have already begun to fail into something better left behind. Trades the
	# melee the arms gave for flight: an extra flap, a glide, the wing skills.
	var wings: EvolvedTraitData = EvolvedTraitData.new()
	wings.id = "wings"
	wings.display_name = "Wings"
	wings.description = "Grow wings over the dead arms: an extra mid-air flap, a glide, and wing dashes."
	wings.flavor = "The forelimb remembers an older use than holding. It opens, and catches the air."
	wings.color = Color("aed6f1")
	wings.replaces_trait = "arms"
	# Arms gone, lungs still intact to drive flight, legs already giving out.
	wings.unlock_conditions = {"arms": [LOST, LOST], "lungs": [INTACT, INTACT], "legs": [PARTIAL, LOST]}
	out.append(wings)

	# Hide — the breath and the gut have both failed, and while the skin still holds
	# it thickens and plates into a hide rather than thinning away. Heavy passive
	# armor, plus the Curl skill to weather a burst.
	var hide: EvolvedTraitData = EvolvedTraitData.new()
	hide.id = "hide"
	hide.display_name = "Hide"
	hide.description = "Thicken the still-whole skin into a plated hide: heavy, permanent damage reduction."
	hide.flavor = "When the inside gives out, the outside answers by hardening."
	hide.color = Color("7f8c8d")
	hide.replaces_trait = "skin"
	hide.hide_damage_mult = 0.6 # 40% flat reduction, far past what intact skin gave.
	# Skin still intact to plate over, lungs and gut both gone.
	hide.unlock_conditions = {"skin": [INTACT, INTACT], "lungs": [LOST, LOST], "gut": [LOST, LOST]}
	out.append(hide)

	return out
