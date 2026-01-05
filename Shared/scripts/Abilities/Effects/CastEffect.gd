extends Effect
class_name CastEffect

## Effect that plays/casts a card from any zone (deck, hand, graveyard, etc.)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var target = parameters.get("Target", "")
	
	if target == "Self":
		# Cast the source card itself (e.g., Eyepatch the Pirate from deck)
		print("🎭 [CAST] Casting ", source_card_data.cardName, " from its current zone")
		
		# Get or create the Card object
		var source_card = source_card_data.get_card_object()
		
		if not source_card or not is_instance_valid(source_card):
			# Card doesn't have an object yet - create it
			source_card = game_context.createCardFromData(source_card_data, source_card_data.playerControlled)
		
		# Use tryPlayCard with pay_cost=false and from_default_zones=false to bypass cost and zone checks
		# The function will handle removing from deck/graveyard and entering the battlefield
		await game_context.tryPlayCard(source_card, game_context.player_base, null, false, false)
	else:
		print("❌ Unsupported Cast target: ", target)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Target")

func get_description(parameters: Dictionary) -> String:
	var target = parameters.get("Target", "Self")
	return "Cast " + target + " from its current zone"
