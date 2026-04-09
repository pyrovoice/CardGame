extends Effect
class_name MoveCardEffect

## Effect that moves a card from one zone to another (e.g., graveyard stealing, library search)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	print("🔍 [MOVE DEBUG] MoveCardEffect.execute called")
	print("  Parameters: ", parameters)
	print("  Source card: ", source_card_data.cardName)
	
	var origin_zone_str: String = parameters.get("Origin", "Graveyard.Player")
	var destination_zone_str: String = parameters.get("Destination", "Graveyard.Opponent")
	var choice_type: String = parameters.get("Choice", "Random")
	var valid_card: String = parameters.get("ValidCard", "Creature")
	var defined: String = parameters.get("Defined", "")
	var condition: String = parameters.get("Condition", "")
	var if_not_found: String = parameters.get("IfNotFound", "")
	var num_cards: int = parameters.get("NumCard", 1)
	
	print("  Defined parameter: '", defined, "' (length: ", defined.length(), ")")
	print("  Origin: ", origin_zone_str)
	print("  Destination: ", destination_zone_str)
	
	# Check condition using controller method
	if condition and not game_context.check_effect_condition(condition, source_card_data):
		print("  ❌ Condition check failed, returning early")
		return
	
	# Determine perspective for zone resolution based on who controls the card
	var from_player_perspective = source_card_data.playerControlled
	print("  From player perspective: ", from_player_perspective)
	
	# Parse zone strings to GameZone.e enums using GameData method
	var origin_zone_enum: GameZone.e = game_context.game_data.parse_zone_string_to_enum(origin_zone_str, from_player_perspective)
	var destination_zone_enum: GameZone.e = game_context.game_data.parse_zone_string_to_enum(destination_zone_str, from_player_perspective)
	
	print("  Origin zone enum: ", origin_zone_enum, " (", GameZone.e.keys()[origin_zone_enum] if origin_zone_enum < GameZone.e.size() else "INVALID", ")")
	print("  Destination zone enum: ", destination_zone_enum, " (", GameZone.e.keys()[destination_zone_enum] if destination_zone_enum < GameZone.e.size() else "INVALID", ")")
	
	if origin_zone_enum == GameZone.e.UNKNOWN or destination_zone_enum == GameZone.e.UNKNOWN:
		push_error("Invalid zones: ", origin_zone_str, " -> ", destination_zone_str)
		print("  ❌ Invalid zones detected, returning early")
		return
	
	# Handle "Defined$ Self" - move the source card itself
	if defined == "Self":
		print("📦 [MOVE DEBUG] Moving self: ", source_card_data.cardName)
		print("  Origin: ", origin_zone_str, " (", origin_zone_enum, ")")
		print("  Destination: ", destination_zone_str, " (", destination_zone_enum, ")")
		print("  Current zone before move: ", game_context.game_data.get_card_zone(source_card_data))
		
		await game_context.execute_move_card(source_card_data, destination_zone_enum, origin_zone_enum)
		
		print("  Current zone after move: ", game_context.game_data.get_card_zone(source_card_data))
		print("  Card in graveyard? ", game_context.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).has(source_card_data))
		return
	
	# Get cards from origin zone using GameData
	var origin_cards: Array[CardData] = game_context.game_data.get_cards_in_zone(origin_zone_enum)
	
	# Filter cards by ValidCard criteria using GameUtility's filtering
	var criteria = GameUtility.parseCriteria(valid_card)
	var filtered_cards: Array[CardData] = []
	for card_data in origin_cards:
		if GameUtility.matchesCardDataCriteria(card_data, criteria):
			filtered_cards.append(card_data)
	
	if filtered_cards.is_empty():
		print("⚠️ No valid cards found in ", origin_zone_str, " matching ", valid_card)
		# Try alternative if specified
		if if_not_found:
			await execute_alternative(if_not_found, parameters, source_card_data, game_context)
		return
	
	# Limit number of cards to available cards
	var cards_to_move = min(num_cards, filtered_cards.size())
	
	# Select cards based on choice type
	var selected_cards: Array[CardData] = []
	if choice_type == "Random":
		# Shuffle and take first N cards
		filtered_cards.shuffle()
		for i in range(cards_to_move):
			selected_cards.append(filtered_cards[i])
	else:
		# TODO: Implement player choice for multiple cards
		for i in range(cards_to_move):
			selected_cards.append(filtered_cards[i])
	
	if selected_cards.is_empty():
		print("⚠️ No cards selected from ", origin_zone_str)
		return
	
	# Move all selected cards
	for selected_card in selected_cards:
		print("📦 ", source_card_data.cardName, " moves ", selected_card.cardName, " from ", origin_zone_str, " to ", destination_zone_str)
		
		# Use game's execute_move_card with GameZone enums
		await game_context.execute_move_card(selected_card, destination_zone_enum, origin_zone_enum)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Origin") and parameters.has("Destination")

func get_description(parameters: Dictionary) -> String:
	var origin = parameters.get("Origin", "unknown")
	var destination = parameters.get("Destination", "unknown")
	var valid_card = parameters.get("ValidCard", "card")
	var num_cards = parameters.get("NumCard", 1)
	var count_text = str(num_cards) + " " + valid_card if num_cards > 1 else valid_card
	return "Move " + count_text + " from " + origin + " to " + destination
