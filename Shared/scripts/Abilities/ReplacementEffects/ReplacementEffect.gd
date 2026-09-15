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
## @param effect_type: EffectType.Type - The type of effect being checked (e.g., EffectType.Type.CREATE_TOKEN)
## @param effect_context: Dictionary - The effect context to check
## @param game_context: Game - The game context for accessing game state
## @return: bool - True if this effect should apply
func applies_to(effect_type: EffectType.Type, effect_context: Dictionary, game_context: Game) -> bool:
	# Check if the source card still exists in game data (headless-safe).
	if not source_card_data:
		return false
	var source_zone = game_context.game_data.get_card_zone(source_card_data)
	if source_zone == GameZone.e.UNKNOWN:
		return false
	
	# Check ActiveZones condition
	var active_zones = conditions.get("ActiveZones", "Any")
	if active_zones != "Any":
		if not _is_zone_valid(active_zones, source_zone):
			return false
	
	# Check event type match
	var required_event_type = conditions.get("EventType", EffectType.Type.NONE)
	if required_event_type == EffectType.Type.NONE:
		return false
	
	if required_event_type != effect_type:
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
			return GameZone.is_in_play(actual_zone)
		"Combat":
			return GameZone.is_combat_zone(actual_zone)
		"Hand":
			return GameZone.is_hand_zone(actual_zone)
		"Graveyard":
			return actual_zone in [GameZone.e.GRAVEYARD_PLAYER, GameZone.e.GRAVEYARD_OPPONENT]
		"Deck":
			return actual_zone in [GameZone.e.DECK_PLAYER, GameZone.e.DECK_OPPONENT]
		_:
			return false
