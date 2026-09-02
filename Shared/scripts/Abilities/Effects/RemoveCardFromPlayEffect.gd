extends Effect
class_name RemoveCardFromPlayEffect

## Effect that completely removes a card from play without moving it to any zone
## The card ceases to exist entirely (not graveyard, not exile)
## Used for replacement effects that need to prevent normal death

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# defined is already parsed by _parse_parameters()
	var card_to_remove: CardData = null
	
	if defined == "Self":
		card_to_remove = source_card_data
	elif target_card:
		card_to_remove = target_card
	else:
		print("⚠️ RemoveCardFromPlayEffect: no valid card to remove")
		return []
	
	if not card_to_remove:
		print("⚠️ RemoveCardFromPlayEffect: card is null")
		return []
	
	print("🗑️ [REMOVE] Completely removing ", card_to_remove.cardName, " from play")
	
	# Get the card's current zone
	var current_zone = game_context.game_data.get_card_zone(card_to_remove)
	if current_zone == GameZone.e.UNKNOWN:
		print("⚠️ Card already not in any zone")
		return []
	
	# Remove from zone tracking
	game_context.game_data.remove_card_from_zone(card_to_remove)
	
	# Destroy the card view if it exists
	var card_node = card_to_remove.get_card_object()
	if card_node and is_instance_valid(card_node):
		card_node.queue_free()
	
	# Clear the reference in CardData
	card_to_remove.card_object = null
	
	print("✅ [REMOVE] ", card_to_remove.cardName, " has been completely removed from the game")
	
	return [card_to_remove]

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Defined") or parameters.has("TargetCard")

func get_description(parameters: Dictionary) -> String:
	var defined_str = parameters.get("Defined", "")
	if defined_str == "Self":
		return "Remove this card from play"
	return "Remove card from play"
