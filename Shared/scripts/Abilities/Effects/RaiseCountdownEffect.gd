extends Effect
class_name RaiseCountdownEffect

## Raises the source card's Countdown by the (possibly alternative) Amount parameter.

func execute(_parameters: Dictionary, source_card_data: CardData, _game_context: Game) -> Array[CardData]:
	if source_card_data.countdown <= 0 or amount <= 0:
		return []
	
	source_card_data.countdown += amount
	source_card_data.dirty_data.emit()
	print("⏫ [COUNTDOWN] ", source_card_data.cardName, " countdown increased by ", amount, " to ", source_card_data.countdown)
	return [source_card_data]

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(_parameters: Dictionary) -> String:
	return "Raise this card's Countdown based on the sacrificed creature's power"
