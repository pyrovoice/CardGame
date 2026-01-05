extends RefCounted
class_name ReplacementEffect

## Base class for replacement effects that modify how effects resolve
## Each replacement effect type should extend this and implement apply_modification()

var source_card_data: CardData  ## The card that provides this replacement effect
var conditions: Dictionary  ## Conditions for when this effect applies (EventType, ActiveZones, ValidToken, etc.)
var modifications: Dictionary  ## The modifications to apply (Type, Amount, etc.)

func _init(source: CardData, cond: Dictionary, mods: Dictionary):
	source_card_data = source
	conditions = cond
	modifications = mods

## Apply the modification to the effect context
## @param effect_context: Dictionary - The effect context being modified
## @param game_context: Game - The game context for accessing game state
## @return: Dictionary - The modified effect context
func apply_modification(effect_context: Dictionary, game_context: Game) -> Dictionary:
	push_error("ReplacementEffect.apply_modification() must be implemented by subclass")
	return effect_context

## Check if this replacement effect applies to the given effect
## @param effect_type: String - The type of effect being checked (e.g., "CreateToken")
## @param effect_context: Dictionary - The effect context to check
## @param game_context: Game - The game context for accessing game state
## @return: bool - True if this effect should apply
func applies_to(effect_type: String, effect_context: Dictionary, game_context: Game) -> bool:
	# Check if the source card is still valid
	var source_card = source_card_data.get_card_object()
	if not source_card or not is_instance_valid(source_card):
		return false
	
	# Check ActiveZones condition
	var active_zones = conditions.get("ActiveZones", "Any")
	if active_zones != "Any":
		var source_zone = game_context.getCardZone(source_card)
		if not _is_zone_valid(active_zones, source_zone):
			return false
	
	# Check event type match
	var required_event_type = conditions.get("EventType", "")
	if required_event_type.is_empty():
		return false
	
	var standardized_required = _standardize_event_type(required_event_type)
	var standardized_actual = _standardize_event_type(effect_type)
	
	if standardized_required != standardized_actual:
		return false
	
	# Check effect-specific conditions (override in subclasses)
	return applies_to_specific(effect_context, game_context)

## Effect-specific condition checking - override in subclasses
## @param effect_context: Dictionary - The effect context to check
## @param game_context: Game - The game context
## @return: bool - True if this effect should apply
func applies_to_specific(effect_context: Dictionary, game_context: Game) -> bool:
	return true

## Validate that required parameters are present
## @param parameters: Dictionary - Effect parameters to validate
## @return: bool - True if parameters are valid
func validate_parameters(parameters: Dictionary) -> bool:
	# Base implementation - override in subclasses for specific validation
	return true

## Get a human-readable description of this effect
## @return: String - Description of the effect
func get_description() -> String:
	return "Generic replacement effect"

## Helper methods

func _is_zone_valid(zone_condition: String, actual_zone: GameZone.e) -> bool:
	"""Check if the actual zone meets the specified zone condition"""
	if zone_condition == "Any":
		return true
	
	match zone_condition:
		"Battlefield":
			return actual_zone == GameZone.e.PLAYER_BASE or actual_zone == GameZone.e.COMBAT_ZONE
		"Hand":
			return actual_zone == GameZone.e.HAND
		"Graveyard":
			return actual_zone == GameZone.e.GRAVEYARD
		"Deck":
			return actual_zone == GameZone.e.DECK
		_:
			return false

func _standardize_event_type(event_type: String) -> String:
	"""Standardize event type strings for comparison"""
	match event_type:
		"CreateToken", "CREATE_TOKEN":
			return "CreateToken"
		"DealDamage", "DEAL_DAMAGE":
			return "DealDamage"
		_:
			return event_type
