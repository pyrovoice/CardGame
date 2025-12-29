extends Effect
class_name DrawCardEffect

## Effect that draws cards

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	# Check who should draw the card (default to "You" if not specified)
	var defined_player = parameters.get("Defined", "You")
	if defined_player != "You":
		print("⚡ Draw card triggered by: ", source_card_data.cardName)
		print("  But effect is for: ", defined_player, " (not implemented for non-player)")
		return
	
	# Get the number of cards to draw
	var cards_to_draw = 1  # Default to 1
	if parameters.has("NumCards"):
		cards_to_draw = int(parameters.get("NumCards", "1"))
	elif parameters.has("Amount"):
		cards_to_draw = int(parameters.get("Amount", "1"))
	elif parameters.has("CardsDrawn"):
		cards_to_draw = int(parameters.get("CardsDrawn", "1"))
	
	print("⚡ Draw card triggered by: ", source_card_data.cardName)
	print("  Drawing ", cards_to_draw, " card(s) for: ", defined_player)
	
	# Draw the specified number of cards
	for i in range(cards_to_draw):
		game_context.drawCard()

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
