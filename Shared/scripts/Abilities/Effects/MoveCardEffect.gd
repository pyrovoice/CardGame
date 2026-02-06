extends Effect
class_name MoveCardEffect

## Effect that moves a card from one zone to another (e.g., graveyard stealing, library search)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var origin_zone_str: String = parameters.get("Origin", "Graveyard.Player")
	var destination_zone_str: String = parameters.get("Destination", "Graveyard.Opponent")
	var choice_type: String = parameters.get("Choice", "Random")
	var valid_card: String = parameters.get("ValidCard", "Creature")
	var condition: String = parameters.get("Condition", "")
	var if_not_found: String = parameters.get("IfNotFound", "")
	var num_cards: int = parameters.get("NumCard", 1)
	
	# Check condition (e.g., "IfAlive" - source card must be alive)
	if condition == "IfAlive":
		var source_card = source_card_data.get_card_object()
		if not source_card or not source_card.is_inside_tree():
			print("⚠️ ", source_card_data.cardName, " is not alive, cannot move card")
			return
	
	# Determine perspective for zone resolution based on who controls the card
	# If player controls it, "Opponent" means opponent's zones
	# If opponent controls it, "Opponent" means player's zones
	var from_player_perspective = source_card_data.playerControlled
	
	# Parse origin and destination zones to get actual zone nodes
	var origin_zone: Node = GameUtility.get_zone_from_string(game_context, origin_zone_str, from_player_perspective)
	var destination_zone: Node = GameUtility.get_zone_from_string(game_context, destination_zone_str, from_player_perspective)
	
	if not origin_zone or not destination_zone:
		push_error("Invalid zones: ", origin_zone_str, " -> ", destination_zone_str)
		return
	
	# Get cards from origin zone
	var origin_cards: Array[CardData] = _get_cards_from_zone_node(origin_zone)
	
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
		
		# Convert Node zones to GameZone.e enums
		var origin_enum = game_context._get_zone_enum(origin_zone)
		var dest_enum = game_context._get_zone_enum(destination_zone)
		
		# Use game's execute_move_card to handle the zone transfer with GameZone enums
		game_context.execute_move_card_from_data(selected_card, origin_enum, dest_enum)

func _get_cards_from_zone_node(zone_node: Node) -> Array[CardData]:
	"""Get all CardData from a zone node - queries GameData instead of containers"""
	var cards: Array[CardData] = []
	
	# Get the Game context to access GameData
	var game_context = zone_node.get_tree().get_first_node_in_group("game") as Game
	if not game_context or not game_context.game_data:
		push_warning("Cannot access GameData from zone node")
		return cards
	
	# Map zone node to GameData zone and query
	var zone_name = game_context._get_zone_type(zone_node)
	match zone_name:
		"Deck":
			# Determine if player or opponent deck
			if zone_node == game_context.deck:
				return game_context.game_data.cards_in_deck_player
			elif zone_node == game_context.deck_opponent:
				return game_context.game_data.cards_in_deck_opponent
		"Graveyard":
			# Determine if player or opponent graveyard
			if zone_node == game_context.graveyard:
				return game_context.game_data.cards_in_graveyard_player
			elif zone_node == game_context.graveyard_opponent:
				return game_context.game_data.cards_in_graveyard_opponent
		"CardHand":
			# Determine if player or opponent hand
			if zone_node == game_context.player_hand:
				return game_context.game_data.cards_in_hand_player
			elif zone_node == game_context.opponent_hand:
				return game_context.game_data.cards_in_hand_opponent
		"PlayerBase":
			# Determine if player or opponent battlefield
			if zone_node == game_context.player_base:
				return game_context.game_data.cards_on_battlefield_player
			elif zone_node == game_context.opponent_base:
				return game_context.game_data.cards_on_battlefield_opponent
		"Combat":
			# Combat zones - get all cards in combat
			var combat_cards: Array[CardData] = []
			for spot in zone_node.get_children():
				if spot is CombatantFightingSpot:
					var card = spot.getCard()
					if card and card.cardData:
						combat_cards.append(card.cardData)
			return combat_cards
	
	push_warning("Unknown or unmapped zone node type: ", zone_name, " (", zone_node.name, ")")
	return cards

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Origin") and parameters.has("Destination")

func get_description(parameters: Dictionary) -> String:
	var origin = parameters.get("Origin", "unknown")
	var destination = parameters.get("Destination", "unknown")
	var valid_card = parameters.get("ValidCard", "card")
	var num_cards = parameters.get("NumCard", 1)
	var count_text = str(num_cards) + " " + valid_card if num_cards > 1 else valid_card
	return "Move " + count_text + " from " + origin + " to " + destination
