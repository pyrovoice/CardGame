extends Effect
class_name LockLocationEffect

## Effect that locks a location against creature plays/moves (for the target's controller side)
## until the location lock is reset at the start of the next turn.
## Expects targets to be pre-resolved and passed in parameters["Targets"] (usually Target$ Self).

func execute(parameters: Dictionary, _source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var target_cards: Array = targets
	if target_cards.is_empty():
		print("⚠️ LockLocationEffect missing pre-resolved Targets")
		return []
	
	for target_card in target_cards:
		var zone = game_context.game_data.get_card_zone(target_card)
		game_context.game_data.lock_location(zone)
		print("🔒 Locked location against creature plays/moves: ", GameZone.get_as_string(zone))
	
	var result: Array[CardData] = []
	result.assign(target_cards)
	return result

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(_parameters: Dictionary) -> String:
	return "Locks this location against creature plays/moves until the end of turn"
