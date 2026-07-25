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


func get_hide_damage_mult() -> float:
	"""Passive damage-taken multiplier from a grown Hide, or 1.0 if not grown."""
	if not has_trait("hide"):
		return 1.0
	for data: EvolvedTraitData in definitions:
		if data.id == "hide":
			return data.hide_damage_mult
	return 1.0


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


func is_eligible(id: String) -> bool:
	"""True when the hidden combo is met and the trait has not yet grown."""
	if _grown.get(id, false):
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


func grow(id: String) -> void:
	if _grown.get(id, false):
		return
	if not _grown.has(id):
		return
	_grown[id] = true
	_offered[id] = true
	# Rebuild the player's live stats (wings glide/flap, hide armor) and re-derive
	# which skills are unlocked now that the evolved pseudo-trait is set.
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
		if data.is_eligible(_trait_manager.traits):
			_offered[data.id] = true
			EventBus.evolved_trait_available.emit(data)
