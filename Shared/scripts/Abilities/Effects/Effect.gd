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
