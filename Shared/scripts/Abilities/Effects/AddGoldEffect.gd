extends Effect
class_name AddGoldEffect

## Adds gold to the controlling player.
##
## Parameters:
##   Amount (int, optional): How much gold to add. Default: 1

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# amount is already parsed by _parse_parameters()
	game_context.game_data.get_gold_pool(source_card_data).value += amount
	return []

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(parameters: Dictionary) -> String:
	var amount = parameters.get("Amount", 1)
	return "Add " + str(amount) + " gold"
