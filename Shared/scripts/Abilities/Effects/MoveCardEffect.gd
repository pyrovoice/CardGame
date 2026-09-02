extends Effect
class_name MoveCardEffect

## Effect that moves a card from one zone to another (e.g., graveyard stealing, library search)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	print("🔍 [MOVE DEBUG] MoveCardEffect.execute called")
	print("  Parameters: ", parameters)
	print("  Source card: ", source_card_data.cardName)
	
	# condition, defined, origin_zone, dest_zone, and targets are already parsed by _parse_parameters()
	print("  Defined parameter: '", defined, "' (length: ", defined.length(), ")")
	print("  Origin zone enum: ", origin_zone)
	print("  Destination zone enum: ", dest_zone)
	
	# Check condition using controller method
	if not condition.is_empty() and not game_context.check_effect_condition(condition, source_card_data):
		print("  ❌ Condition check failed, returning early")
		return []
	
	# Affected$ Card.Remembered — operate on remembered cards, bypassing zone filtering
	var affected = Effect.resolve_affected(parameters)
	if not affected.is_empty():
		var moved: Array[CardData] = []
		for card in affected:
			await game_context.execute_move_card(card, dest_zone)
			moved.append(card)
		return moved
	
	# Pre-selected Targets (from upfront spell targeting via ValidTgts$) —
	# move each specific card to the destination, regardless of its current zone.
	if not targets.is_empty():
		var moved: Array[CardData] = []
		for card in targets:
			await game_context.execute_move_card(card, dest_zone)
			moved.append(card)
		return moved
	
	# Determine perspective for zone resolution based on who controls the card
	var from_player_perspective = source_card_data.playerControlled
	print("  From player perspective: ", from_player_perspective)
	
	print("  Origin zone enum: ", origin_zone, " (", GameZone.e.keys()[origin_zone] if origin_zone < GameZone.e.size() else "INVALID", ")")
	print("  Destination zone enum: ", dest_zone, " (", GameZone.e.keys()[dest_zone] if dest_zone < GameZone.e.size() else "INVALID", ")")
	
	if origin_zone == GameZone.e.UNKNOWN or dest_zone == GameZone.e.UNKNOWN:
		push_error("Invalid zones detected")
		print("  ❌ Invalid zones detected, returning early")
		return []
	
	# Handle "Defined$ Self" - move the source card itself
	if defined == "Self":
		print("📦 [MOVE DEBUG] Moving self: ", source_card_data.cardName)
		print("  Origin zone enum: ", origin_zone)
		print("  Destination zone enum: ", dest_zone)
		print("  Current zone before move: ", game_context.game_data.get_card_zone(source_card_data))
		
		await game_context.execute_move_card(source_card_data, dest_zone, origin_zone)
		
		print("  Current zone after move: ", game_context.game_data.get_card_zone(source_card_data))
		print("  Card in graveyard? ", game_context.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).has(source_card_data))
		return [source_card_data]
	
	# Get cards from origin zone using GameData
	var origin_cards: Array[CardData] = game_context.game_data.get_cards_in_zone(origin_zone)
	
	# Filter and select cards using base class method
	var selected_cards = await filter_and_select_cards(
		origin_cards,
		parameters,
		GameZone.e.keys()[origin_zone],
		"Move Card",
		source_card_data,
		game_context
	)
	
	if selected_cards.is_empty():
		print("⚠️ No cards selected from origin zone")
		return []
	
	# Move all selected cards
	for selected_card in selected_cards:
		print("📦 ", source_card_data.cardName, " moves ", selected_card.cardName, " to destination")
		await game_context.execute_move_card(selected_card, dest_zone, origin_zone)
	
	return selected_cards

func can_execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> bool:
	"""Returns false when no valid cards exist in the origin zone (or condition fails)."""
	print("🔍 [MOVE CAN_EXECUTE] Called with parameters: ", parameters.keys())
	print("  Has Targets in parameters: ", parameters.has("Targets"))
	if parameters.has("Targets"):
		print("  Targets count: ", parameters.get("Targets", []).size())
	
	# Base class handles pre-selected targets, conditions, and parsing
	var super_result = super.can_execute(parameters, source_card_data, game_context)
	print("🔍 [MOVE CAN_EXECUTE] super.can_execute returned: ", super_result)
	print("  targets instance var size: ", targets.size())
	print("  defined: '", defined, "'")
	print("  origin_zone: ", origin_zone)
	
	if not super_result:
		return false

	# If base class returned true and we have pre-selected targets, we're good
	if not targets.is_empty():
		print("  ✅ Pre-selected targets exist - returning true")
		return true

	if defined == "Self":
		print("  ✅ Self move - returning true")
		return true  # Moving self is always a valid action

	if origin_zone == GameZone.e.UNKNOWN:
		print("  ❌ Unknown origin zone - returning false")
		return false

	var origin_cards: Array[CardData] = game_context.game_data.get_cards_in_zone(origin_zone)
	print("  origin_cards count: ", origin_cards.size())

	if valid_card.is_empty():
		var result = not origin_cards.is_empty()
		print("  No ValidCard filter, result: ", result)
		return result

	var criteria = GameUtility.parseCriteria(valid_card)
	for card in origin_cards:
		if GameUtility.matchesCardDataCriteria(card, criteria):
			print("  ✅ Found matching card - returning true")
			return true

	print("  ❌ No matching cards found - returning false")
	return false

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Origin") and parameters.has("Destination")

func get_description(parameters: Dictionary) -> String:
	var origin = parameters.get("Origin", "unknown")
	var destination = parameters.get("Destination", "unknown")
	var valid_card = parameters.get("ValidCard", "card")
	var num_cards = parameters.get("NumCard", 1)
	var count_text = str(num_cards) + " " + valid_card if num_cards > 1 else valid_card
	return "Move " + count_text + " from " + origin + " to " + destination
