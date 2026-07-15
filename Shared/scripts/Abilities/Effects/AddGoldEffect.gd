extends Effect
class_name AddGoldEffect

## Adds gold to the controlling player.
##
## Parameters:
##   Amount (int, optional): How much gold to add. Default: 1

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var amount = parameters.get("Amount", 1)
	if source_card_data.playerControlled:
		game_context.game_data.player_gold.value += amount
	else:
		game_context.game_data.opponent_gold.value += amount
	return []

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(parameters: Dictionary) -> String:
	var amount = parameters.get("Amount", 1)
	return "Add " + str(amount) + " gold"
