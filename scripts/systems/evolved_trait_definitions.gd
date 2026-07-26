# evolved_trait_definitions.gd
# Static factory for the evolved traits — the hidden "grow it back" options.
#
# Each one is revealed by a specific combination of losses and, if accepted, takes
# over the role of a trait slot. They are the counterweight to pure devolution: the
# run only strips you down, but a few of those stripped states open an older shape
# underneath. Add one by appending to get_all().
#
# PLANNING1 section 6 "traits regained" named six: Wings, Hide, Tail, Claws, Plates,
# Gills. They pair off by slot, and a slot only ever holds one of them
# (EvolvedTraitManager enforces it), so each pair is a fork rather than a checklist:
#
#   arms  -> Wings  (flee and traverse)   vs. Claws  (keep fighting)
#   skin  -> Hide   (thick, if it held)   vs. Plates (salvaged, if it did not)
#   legs  -> Tail   (balance in the air)
#   lungs -> Gills  (breathe another way)
class_name EvolvedTraitDefinitions
extends RefCounted

const INTACT: int = 0
const PARTIAL: int = 1
const LOST: int = 2


static func get_all() -> Array[EvolvedTraitData]:
	var out: Array[EvolvedTraitData] = []

	# ------------------------------------------------------- arms slot ----

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

	# Claws — the other thing an arm can become. With the skin stripped away too there
	# is nothing left to protect, so the limb commits entirely to the attack: shorter
	# reach than a hand ever had, but it gives the melee back after the arms are gone.
	# The opposite bargain to Wings, and the slot only holds one of them.
	var claws: EvolvedTraitData = EvolvedTraitData.new()
	claws.id = "claws"
	claws.display_name = "Claws"
	claws.description = "Grow claws over the dead arms: your attack works again, harder but far shorter."
	claws.flavor = "It stopped trying to hold anything. What is left of the hand only closes."
	claws.color = Color("e8dcc8")
	claws.replaces_trait = "arms"
	claws.restores_attack = true
	claws.attack_damage_mult = 1.15 # Harder than an intact arm ever swung...
	claws.attack_range_mult = 0.5   # ...but you have to be right on top of it.
	claws.attack_bleed_dps = 4.0    # ...and every swing leaves the wound open.
	claws.attack_bleed_time = 3.0
	# Arms gone and skin gone: nothing to protect, so the limb becomes the weapon.
	claws.unlock_conditions = {"arms": [LOST, LOST], "skin": [LOST, LOST]}
	out.append(claws)

	# ------------------------------------------------------- skin slot ----

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
	hide.damage_taken_mult = 0.6 # 40% flat reduction, far past what intact skin gave.
	# Skin still intact to plate over, lungs and gut both gone.
	hide.unlock_conditions = {"skin": [INTACT, INTACT], "lungs": [LOST, LOST], "gut": [LOST, LOST]}
	out.append(hide)

	# Plates — what the skin slot offers once the skin is already gone. Bone grows out
	# through where it used to be: thinner protection than a Hide, but the weight of it
	# makes you very hard to move. Consolation armor for a run that lost its skin early.
	var plates: EvolvedTraitData = EvolvedTraitData.new()
	plates.id = "plates"
	plates.display_name = "Plates"
	plates.description = "Push bone plates out through the bare flesh: solid protection, and almost immovable."
	plates.flavor = "The skin did not survive. The skeleton takes over the job of being an outside."
	plates.color = Color("a1887f")
	plates.replaces_trait = "skin"
	plates.damage_taken_mult = 0.7 # Less than a Hide — this is salvage, not growth.
	plates.knockback_resist = 0.65 # But nothing shifts you.
	# The skin is already gone and the gut with it.
	plates.unlock_conditions = {"skin": [LOST, LOST], "gut": [LOST, LOST]}
	out.append(plates)

	# ------------------------------------------------------- legs slot ----

	# Tail — the legs are failing and the head's readouts are gone, so balance stops
	# being something you calculate and becomes something you carry. Mid-air steering
	# and a much longer window to leave a ledge.
	var tail: EvolvedTraitData = EvolvedTraitData.new()
	tail.id = "tail"
	tail.display_name = "Tail"
	tail.description = "Regrow a tail: real steering in mid-air, a far longer ledge window, and a whip attack."
	tail.flavor = "Balance stops being a thing it works out, and goes back to being a thing it has."
	tail.color = Color("bb8fce")
	tail.replaces_trait = "legs"
	tail.air_control_mult = 1.9
	tail.coyote_bonus = 0.12 # On top of the base 0.08 — a genuinely forgiving window.
	# Legs half gone, head gone: no more thinking your way across a gap.
	tail.unlock_conditions = {"legs": [PARTIAL, PARTIAL], "head": [LOST, LOST]}
	out.append(tail)

	# ------------------------------------------------------ lungs slot ----

	# Gills — the lungs are ruined and the eyes with them. Breathing moves somewhere
	# older and stops pacing the body: the swing recovery the failing lungs imposed is
	# lifted entirely. (Water terrain, ideate 3.3, is where this earns its second half.)
	var gills: EvolvedTraitData = EvolvedTraitData.new()
	gills.id = "gills"
	gills.display_name = "Gills"
	gills.description = "Open gills where the lungs failed: your swing recovery goes back to whole."
	gills.flavor = "It gave up on air. Something further back down the line never needed it."
	gills.color = Color("76d7c4")
	gills.replaces_trait = "lungs"
	gills.attack_cooldown_mult = 1.0 # Cancels the lungs' 2.2x penalty outright.
	# Lungs gone and eyes gone — the body retreating to an older, dimmer way of being.
	gills.unlock_conditions = {"lungs": [LOST, LOST], "eyes": [LOST, LOST]}
	out.append(gills)

	return out
