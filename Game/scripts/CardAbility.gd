class_name CardAbility extends RefCounted

var owner_card_data: WeakRef  # Reference to the CardData that owns this ability
var effect_type: EffectType.Type  # What effect does this ability have
var effect_parameters: Dictionary  # Parameters for the effect (token name, damage amount, etc.)
var targeting_requirements: Dictionary  # For abilities that need targets
var description = ""

# Exhaustion/refresh state - shared by triggered, activated and replacement abilities.
# Not all ability types currently wire up automatic refresh (see each subclass).
var exhausted: bool = false  # True once this ability has resolved/activated/replaced since its last refresh
var refreshes_on_turn_start: bool = true  # If true, auto-refreshes at Beginning of Turn
var exhausts_on_use: bool = true  # If false, resolving/activating/replacing never sets exhausted (Activated/Replacement default)
var is_one_time: bool = false  # If true, this ability can only ever resolve once - refresh never brings it back
var _used_up: bool = false  # Permanent flag for one-time abilities that already resolved once

func _init(p_owner: CardData):
	owner_card_data = weakref(p_owner)
	effect_parameters = {}
	targeting_requirements = {}

func is_available() -> bool:
	"""Whether this ability is currently allowed to trigger/activate/replace"""
	return not exhausted and not _used_up

func mark_exhausted() -> void:
	"""Mark this ability as exhausted - call when it actually resolves/activates/replaces"""
	if is_one_time:
		_used_up = true
	if exhausts_on_use:
		exhausted = true

func refresh() -> void:
	"""Clear the exhausted state. Does not revive a one-time ability that already resolved."""
	exhausted = false

## Builder methods for configuring abilities

func with_effect_parameters(params: Dictionary) -> CardAbility:
	"""Set effect parameters (token name, damage amount, etc.)"""
	effect_parameters = params
	return self



func with_targeting(target_params: Dictionary) -> CardAbility:
	"""Set targeting requirements"""
	targeting_requirements = target_params
	return self

## Query methods

func has_targeting() -> bool:
	return not targeting_requirements.is_empty()

func get_owner() -> CardData:
	"""Get the CardData that owns this ability"""
	if owner_card_data:
		return owner_card_data.get_ref()
	return null

func requires_target() -> bool:
	"""Check if this ability requires selecting a target"""
	return has_targeting() and targeting_requirements.get("required", false)

func get_description() -> String:
	"""Get a human-readable description of this ability"""
	var desc = EffectType.type_to_string(effect_type)
	
	# Add key parameters to description
	if effect_parameters.has("token_name"):
		desc += " (Token: " + str(effect_parameters["token_name"]) + ")"
	elif effect_parameters.has("NumDamage"):
		desc += " (" + str(effect_parameters["NumDamage"]) + " damage)"
	elif effect_parameters.has("NumDraw"):
		desc += " (Draw " + str(effect_parameters["NumDraw"]) + ")"
	
	return desc