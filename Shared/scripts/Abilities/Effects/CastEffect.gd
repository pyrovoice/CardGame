extends Effect
class_name CastEffect

## Effect that plays/casts a card from any zone (deck, hand, graveyard, etc.)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var target = parameters.get("Target", "")
	
	if target == "Self":
		# Cast the source card itself (e.g., Eyepatch the Pirate from deck)
		print("🎭 [CAST] Casting ", source_card_data.cardName, " from its current zone")
		
		# Try to get the Card object to determine zone
		var source_card = source_card_data.get_card_object()
		
		# Determine current zone
		var current_zone: GameZone.e
		if source_card and is_instance_valid(source_card):
			current_zone = game_context.getCardZone(source_card)
		else:
			# Card object doesn't exist yet - must be in deck or hand as CardData
			# Check deck first
			var deck_to_check = game_context.deck if source_card_data.playerControlled else game_context.deck_opponent
			if deck_to_check.cards.has(source_card_data):
				current_zone = GameZone.e.DECK
			else:
				# Must be in hand
				var hand_to_check = game_context.hand if source_card_data.playerControlled else game_context.hand_opponent
				if hand_to_check.cards.has(source_card_data):
					current_zone = GameZone.e.HAND
				else:
					print("❌ Cannot find card in any zone")
					return
		
		print("  Current zone: ", GameZone.zoneToString(current_zone))
		
		# Cast/play the card
		match current_zone:
			GameZone.e.DECK:
				# Play from deck - move to battlefield
				print("  Playing from deck to battlefield")
				await game_context.playCardFromDeck(source_card_data)
			
			GameZone.e.HAND:
				# Play from hand - use normal play mechanism
				print("  Playing from hand (TODO: implement)")
				# TODO: Implement playing from hand
			
			GameZone.e.GRAVEYARD:
				# Play from graveyard
				print("  Playing from graveyard (TODO: implement)")
				# TODO: Implement playing from graveyard
			
			_:
				print("❌ Cannot cast from zone: ", GameZone.zoneToString(current_zone))
	else:
		print("❌ Unsupported Cast target: ", target)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Target")

func get_description(parameters: Dictionary) -> String:
	var target = parameters.get("Target", "Self")
	return "Cast " + target + " from its current zone"
