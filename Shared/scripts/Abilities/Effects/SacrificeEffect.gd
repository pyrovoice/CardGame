extends Effect
class_name SacrificeEffect

## Effect that sacrifices cards (moves them to their owner's graveyard)
## Can target specific cards or filter cards in play

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	print("💀 [SACRIFICE] Executing sacrifice effect")
	
	# Check if we have a specific target card (used by orphaned abilities from CreateDelayedEffect)
	var target_card: CardData = parameters.get("TargetCard", null)
	
	if target_card:
		# Sacrifice specific card
		await _sacrifice_card(target_card, game_context)
		return
	
	# Otherwise, gather cards matching criteria
	var defined: String = parameters.get("Defined", "")
	var valid_cards: String = parameters.get("ValidCards", "Card.YouCtrl")
	var num_cards: int = parameters.get("Num", 1)
	
	# Handle "Defined$ Self" - sacrifice the source card
	if defined == "Self":
		await _sacrifice_card(source_card_data, game_context)
		return
	
	# Gather cards matching ValidCards filter
	var matching_cards = game_context._matches_card_filter(valid_cards)
	
	if matching_cards.is_empty():
		print("⚠️ No valid cards to sacrifice matching: ", valid_cards)
		return
	
	# Sacrifice up to num_cards
	var cards_to_sacrifice = matching_cards.slice(0, min(num_cards, matching_cards.size()))
	
	for card in cards_to_sacrifice:
		await _sacrifice_card(card, game_context)

func _sacrifice_card(card_data: CardData, game_context: Game):
	"""Move a card to its owner's graveyard"""
	if not card_data:
		return
	
	# Check if card is in play
	var current_zone = game_context.game_data.get_card_zone(card_data)
	if not GameZone.is_in_play(current_zone):
		print("⚠️ Cannot sacrifice ", card_data.cardName, " - not in play (zone: ", GameZone.e.keys()[current_zone], ")")
		return
	
	# Determine graveyard zone based on owner
	var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
	
	print("💀 Sacrificing ", card_data.cardName, " to graveyard")
	await game_context.execute_move_card(card_data, graveyard_zone, current_zone)

func validate_parameters(parameters: Dictionary) -> bool:
	# Valid if we have TargetCard, Defined, or ValidCards
	return parameters.has("TargetCard") or parameters.has("Defined") or parameters.has("ValidCards")

func get_description(parameters: Dictionary) -> String:
	var target_card: CardData = parameters.get("TargetCard", null)
	if target_card:
		return "Sacrifice " + target_card.cardName
	
	var defined: String = parameters.get("Defined", "")
	if defined == "Self":
		return "Sacrifice this card"
	
	var valid_cards: String = parameters.get("ValidCards", "Card")
	var num: int = parameters.get("Num", 1)
	
	if num == 1:
		return "Sacrifice a " + valid_cards
	else:
		return "Sacrifice " + str(num) + " " + valid_cards
