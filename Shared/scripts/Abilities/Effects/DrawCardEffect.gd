extends Effect
class_name DrawCardEffect

## Effect that draws cards

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# defined and amount are already parsed by _parse_parameters()
	if defined != "You":
		print("⚡ Draw card triggered by: ", source_card_data.cardName)
		print("  But effect is for: ", defined, " (not implemented for non-player)")
		return []
	
	# amount holds the number of cards to draw
	var cards_to_draw = amount
	
	print("⚡ Draw card triggered by: ", source_card_data.cardName)
	print("  Drawing ", cards_to_draw, " card(s) for: ", defined)
	
	# Draw the specified number of cards
	for i in range(cards_to_draw):
		game_context.drawCard()

	return []

func validate_parameters(_parameters: Dictionary) -> bool:
	# Draw card can work with defaults, so always valid
	return true

func get_description(parameters: Dictionary) -> String:
	var num_cards = 1
	if parameters.has("NumCards"):
		num_cards = int(parameters.get("NumCards", "1"))
	elif parameters.has("Amount"):
		num_cards = int(parameters.get("Amount", "1"))
	
	var player = parameters.get("Defined", "You")
	return player + " draw" + ("s" if player == "You" else "") + " " + str(num_cards) + " card" + ("s" if num_cards > 1 else "")
