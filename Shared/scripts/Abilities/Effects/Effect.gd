extends RefCounted
class_name Effect

## Base class for all ability effects
## Each effect type should extend this and implement execute()

## Execute the effect
## @param parameters: Dictionary - Effect-specific parameters
## @param source_card_data: CardData - The card that is the source of this effect
## @param game_context: Game - The game context for accessing game state
## @return: void (use await if the effect is async)
func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	push_error("Effect.execute() must be implemented by subclass")
	pass

## Validate that required parameters are present
## @param parameters: Dictionary - Effect parameters to validate
## @return: bool - True if parameters are valid
func validate_parameters(parameters: Dictionary) -> bool:
	# Base implementation - override in subclasses for specific validation
	return true

## Get a human-readable description of this effect
## @param parameters: Dictionary - Effect parameters
## @return: String - Description of the effect
func get_description(parameters: Dictionary) -> String:
	return "Generic effect"

## Execute an alternative effect if specified in parameters
## @param alternative_name: String - Name of the alternative effect (from IfNotFound parameter)
## @param parameters: Dictionary - Current effect parameters
## @param source_card_data: CardData - The card that is the source of this effect
## @param game_context: Game - The game context for accessing game state
## @return: bool - True if alternative was executed, false if not found
func execute_alternative(alternative_name: String, parameters: Dictionary, source_card_data: CardData, game_context: Game) -> bool:
	"""Execute an alternative effect by looking up alternative parameters"""
	if not alternative_name:
		return false
	
	# Look for alternative effect parameters embedded in the main parameters
	var alternative_params_key = "Alternative_" + alternative_name
	if not parameters.has(alternative_params_key):
		print("⚠️ Alternative effect '", alternative_name, "' not found in parameters")
		return false
	
	var alternative_params = parameters.get(alternative_params_key, {})
	if alternative_params.is_empty():
		print("⚠️ Alternative effect '", alternative_name, "' has no parameters")
		return false
	
	# Get the effect type for the alternative
	var alt_effect_type_str = alternative_params.get("EffectType", "")
	if alt_effect_type_str.is_empty():
		print("⚠️ Alternative effect '", alternative_name, "' has no EffectType")
		return false
	
	var alt_effect_type = EffectType.string_to_type(alt_effect_type_str)
	
	print("🔄 Executing alternative effect: ", alternative_name, " (", alt_effect_type_str, ")")
	
	# Execute the alternative effect using EffectFactory
	await EffectFactory.execute_effect(alt_effect_type, alternative_params, source_card_data, game_context)
	
	return true
