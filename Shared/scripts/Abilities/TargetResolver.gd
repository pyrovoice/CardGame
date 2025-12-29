extends RefCounted
class_name TargetResolver

## Resolves targets for ability effects based on targeting parameters
## Handles ValidCards, Target specifications, and filtering

static func resolve_targets(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[Card]:
	"""
	Resolve targets for an ability effect based on parameters.
	
	@param parameters: Dictionary containing targeting info:
		- Target: String - Target specification ("Self", "All", etc.)
		- ValidCards: String - Card filter ("Creature.YouCtrl", etc.)
		- ValidTargets: String - Alternative to ValidCards
		- Targets: Array[Card] - Pre-selected targets (if already resolved)
	@param source_card_data: CardData - The card creating the effect
	@param game_context: Game - The game context
	@return: Array[Card] - Resolved target cards
	"""
	
	# Check if targets are already pre-resolved
	var preselected_targets = parameters.get("Targets", [])
	if not preselected_targets.is_empty():
		return preselected_targets
	
	# Parse target specification
	var target_spec = parameters.get("Target", "")
	var valid_cards = parameters.get("ValidCards", parameters.get("ValidTargets", "Any"))
	
	# Handle special target specifications
	match target_spec:
		"Self":
			return _resolve_self_target(source_card_data)
		"All":
			return find_valid_cards(valid_cards, game_context)
		"":
			# No target spec - use ValidCards/ValidTargets to find all matching
			if valid_cards != "Any":
				return find_valid_cards(valid_cards, game_context)
			else:
				return []
		_:
			print("⚠️ Unknown target specification: ", target_spec)
			return []

static func _resolve_self_target(source_card_data: CardData) -> Array[Card]:
	"""Resolve 'Self' target to the source card"""
	var source_card = source_card_data.get_card_object()
	if source_card:
		return [source_card]
	else:
		print("⚠️ Cannot resolve Self target - card no longer exists")
		return []

static func find_valid_cards(condition: String, game_context: Game) -> Array[Card]:
	"""
	Find all cards matching the given condition.
	
	@param condition: String - Filter condition (e.g., "Creature.YouCtrl", "Card.Other+Goblin")
	@param game_context: Game - The game context
	@return: Array[Card] - Cards matching the condition
	"""
	if condition == "Any":
		return game_context.getAllCardsInPlay()
	
	var all_cards = game_context.getAllCardsInPlay()
	var valid_targets: Array[Card] = []
	
	for card in all_cards:
		if is_valid_card_for_condition(card, condition):
			valid_targets.append(card)
	
	return valid_targets

static func is_valid_card_for_condition(card: Card, condition: String) -> bool:
	"""
	Check if a card matches the given condition string.
	
	Supported formats:
	- "Creature" - Must be a creature
	- "Creature.YouCtrl" - Must be a creature you control
	- "Card.Other+Goblin" - Must not be Self and must be a Goblin
	- "Spell" - Must be a spell
	"""
	if condition == "Any":
		return true
	
	# Parse condition format: "Type.Modifier+Subtype" etc.
	# Handle "+" separated conditions (AND logic)
	var and_parts = condition.split("+")
	
	for and_part in and_parts:
		and_part = and_part.strip_edges()
		
		# Handle "." separated conditions within each AND part
		var dot_parts = and_part.split(".")
		
		for part in dot_parts:
			part = part.strip_edges()
			
			if not _check_condition_part(card, part):
				return false
	
	return true

static func _check_condition_part(card: Card, part: String) -> bool:
	"""Check if a card matches a single condition part"""
	match part:
		"Card":
			# Generic card reference, always true
			return true
		
		"Other":
			# This needs context of the source card, should be handled at ability level
			# For now, always return true and let ability level handle it
			return true
		
		"Creature":
			return card.cardData.hasType(CardData.CardType.CREATURE)
		
		"Spell":
			return card.cardData.hasType(CardData.CardType.SPELL)
		
		"YouCtrl":
			return card.cardData.playerControlled
		
		"OppCtrl":
			return not card.cardData.playerControlled
		
		_:
			# Check if it's a card type
			if CardData.isValidCardTypeString(part):
				var card_type = CardData.stringToCardType(part)
				return card.cardData.hasType(card_type)
			else:
				# Assume it's a subtype
				return card.cardData.hasSubtype(part)
	
	return false

static func filter_out_source(cards: Array[Card], source_card_data: CardData) -> Array[Card]:
	"""Remove the source card from a list of cards (for 'Other' conditions)"""
	var source_card = source_card_data.get_card_object()
	if not source_card:
		return cards
	
	var filtered: Array[Card] = []
	for card in cards:
		if card != source_card:
			filtered.append(card)
	
	return filtered
