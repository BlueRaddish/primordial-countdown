# evolved_trait_manager.gd
# Tracks the evolved ("grown back") traits. Child node of Player, sibling of
# TraitManager.
#
# Flow:
#   1. A devolution changes a base trait -> trait_changed fires.
#   2. This manager checks, deferred (so it lands after the devolution popup has
#      closed), whether any dormant evolved trait's hidden combo is now met.
#   3. The first time one becomes eligible it emits evolved_trait_available, which
#      the evolved-trait popup turns into an accept/decline offer.
#   4. grow() marks it grown, rebuilds player stats, and refreshes skills. A
#      declined offer is not re-popped, but stays claimable from the character
#      screen for as long as it remains eligible.
#
# One evolved trait per slot. Each definition names the base trait it grows over
# (replaces_trait), and once something occupies that slot every rival for it is
# closed off permanently — growing Wings ends any chance of Claws. The run is a
# body forced down one path; being able to grow everything would make it a power
# fantasy instead of a devolution.
#
# Evolved traits also act as pseudo-traits (stage 0 dormant, 1 grown) for skill
# unlocking; AbilityManager reads get_evolved_states() and merges it in.
class_name EvolvedTraitManager
extends Node

var definitions: Array[EvolvedTraitData] = []

# id -> bool. Whether each evolved trait has grown in.
var _grown: Dictionary = {}
# id -> bool. Whether we have already surfaced the offer once (so it isn't spammed
# on every subsequent devolution).
var _offered: Dictionary = {}

var _trait_manager: TraitManager


func _ready() -> void:
	add_to_group("evolved_trait_manager")
	definitions = EvolvedTraitDefinitions.get_all()
	for data: EvolvedTraitData in definitions:
		_grown[data.id] = false
		_offered[data.id] = false
	EventBus.trait_changed.connect(_on_trait_changed)
	call_deferred("_find_trait_manager")


func _find_trait_manager() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_node("TraitManager"):
		_trait_manager = parent.get_node("TraitManager") as TraitManager


# ---- Public API ----

func has_trait(id: String) -> bool:
	return _grown.get(id, false)


func get_evolved_states() -> Dictionary:
	"""Pseudo-trait states for skill unlocking: id -> 0 dormant / 1 grown."""
	var states: Dictionary = {}
	for id: String in _grown:
		states[id] = 1 if _grown[id] else 0
	return states


func get_definition(id: String) -> EvolvedTraitData:
	for data: EvolvedTraitData in definitions:
		if data.id == id:
			return data
	return null


func get_grown() -> Array[EvolvedTraitData]:
	var out: Array[EvolvedTraitData] = []
	for data: EvolvedTraitData in definitions:
		if _grown.get(data.id, false):
			out.append(data)
	return out


# ---- Slot exclusivity ----

func get_slot_owner(slot: String) -> EvolvedTraitData:
	"""The grown evolved trait occupying a base-trait slot, or null if it is open."""
	for data: EvolvedTraitData in definitions:
		if _grown.get(data.id, false) and data.replaces_trait == slot:
			return data
	return null


func get_blocker(id: String) -> EvolvedTraitData:
	"""The already-grown trait that has closed this one off, or null."""
	var data: EvolvedTraitData = get_definition(id)
	if not data:
		return null
	var owner: EvolvedTraitData = get_slot_owner(data.replaces_trait)
	if owner and owner.id != id:
		return owner
	return null


func get_rivals(id: String) -> Array[EvolvedTraitData]:
	"""Other evolved traits that grow from the same slot, so accepting this one
	permanently closes them off. Used to warn the player before they commit."""
	var out: Array[EvolvedTraitData] = []
	var data: EvolvedTraitData = get_definition(id)
	if not data:
		return out
	for other: EvolvedTraitData in definitions:
		if other.id != id and other.replaces_trait == data.replaces_trait:
			out.append(other)
	return out


func is_eligible(id: String) -> bool:
	"""True when the hidden combo is met, the trait has not grown, and nothing else
	has already taken its slot."""
	if _grown.get(id, false):
		return false
	if get_blocker(id) != null:
		return false
	var data: EvolvedTraitData = get_definition(id)
	if not data or not _trait_manager:
		return false
	return data.is_eligible(_trait_manager.traits)


func get_claimable() -> Array[EvolvedTraitData]:
	"""Eligible-but-dormant evolved traits, for the character screen to offer."""
	var out: Array[EvolvedTraitData] = []
	for data: EvolvedTraitData in definitions:
		if is_eligible(data.id):
			out.append(data)
	return out


# ---- Aggregate stat payloads ----
#
# Several evolved traits can be grown at once (one per slot), so the payloads are
# combined here rather than in the player. Overrides return 0.0 when no grown trait
# has anything to say about that stat.

func get_damage_taken_mult() -> float:
	"""Strongest passive protection among grown traits. 1.0 = none."""
	var best: float = 1.0
	for data: EvolvedTraitData in get_grown():
		best = minf(best, data.damage_taken_mult)
	return best


func get_knockback_resist() -> float:
	var best: float = 0.0
	for data: EvolvedTraitData in get_grown():
		best = maxf(best, data.knockback_resist)
	return best


func get_air_control_mult() -> float:
	var best: float = 1.0
	for data: EvolvedTraitData in get_grown():
		best = maxf(best, data.air_control_mult)
	return best


func get_coyote_bonus() -> float:
	var best: float = 0.0
	for data: EvolvedTraitData in get_grown():
		best = maxf(best, data.coyote_bonus)
	return best


func get_attack_restorer() -> EvolvedTraitData:
	"""The grown trait that hands the melee attack back (Claws), or null."""
	for data: EvolvedTraitData in get_grown():
		if data.restores_attack:
			return data
	return null


func get_attack_cooldown_override() -> float:
	"""Swing-recovery multiplier from a grown trait (Gills), or 0.0 if none."""
	for data: EvolvedTraitData in get_grown():
		if data.attack_cooldown_mult > 0.0:
			return data.attack_cooldown_mult
	return 0.0


# ---- Mutation ----

func grow(id: String) -> void:
	if _grown.get(id, false):
		return
	if not _grown.has(id):
		return
	# Refuse if a rival already holds the slot. Nothing should offer a blocked trait,
	# but the character screen and the popup both call in here, so this is the one
	# place that has to be certain.
	if get_blocker(id) != null:
		return

	_grown[id] = true
	_offered[id] = true
	# Everything sharing this slot is now permanently closed off. Marking them
	# offered keeps them out of any later popup even if their combo comes true.
	for rival: EvolvedTraitData in get_rivals(id):
		_offered[rival.id] = true

	# Rebuild the player's live stats (wings glide, claws attack, plate armor) and
	# re-derive which skills are unlocked now that the evolved pseudo-trait is set.
	if _trait_manager:
		_trait_manager.recalculate_all()
	EventBus.evolved_trait_grown.emit(id)


func decline(id: String) -> void:
	"""Dismiss the offer for now. Stays claimable from the character screen."""
	_offered[id] = true


func reset_all() -> void:
	for id: String in _grown:
		_grown[id] = false
		_offered[id] = false
	if _trait_manager:
		_trait_manager.recalculate_all()


# ---- Detection ----

func _on_trait_changed(_trait_name: String, _new_stage: int) -> void:
	# Deferred so the offer surfaces after the devolution popup that caused it has
	# closed, rather than stacking on top of it in the same frame.
	call_deferred("_check_offers")


func _check_offers() -> void:
	if not _trait_manager:
		_find_trait_manager()
	if not _trait_manager:
		return
	for data: EvolvedTraitData in definitions:
		if _grown.get(data.id, false) or _offered.get(data.id, false):
			continue
		if get_blocker(data.id) != null:
			continue
		if data.is_eligible(_trait_manager.traits):
			_offered[data.id] = true
			EventBus.evolved_trait_available.emit(data)
