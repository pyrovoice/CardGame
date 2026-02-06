extends RefCounted
class_name TargetResolver

## Resolves targets for ability effects based on targeting parameters
## Handles ValidCards, Target specifications, and filtering

static func resolve_targets(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array:
	"""
	Resolve targets for an ability effect based on parameters.
	
	@param parameters: Dictionary containing targeting info:
		- Target: String - Target specification ("Self", "All", etc.)
		- ValidCards: String - Card filter ("Creature.YouCtrl", etc.)
		- ValidTargets: String - Alternative to ValidCards
		- Targets: Array - Pre-selected targets (CardData if already resolved)
	@param source_card_data: CardData - The card creating the effect
	@param game_context: Game - The game context
	@return: Array - Resolved target cards (CardData for pre-selected, Card for resolved)
	"""
	
	# Check if targets are already pre-resolved (now CardData)
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

static func _resolve_self_target(source_card_data: CardData) -> Array:
	"""Resolve 'Self' target to the source card (returns CardData for consistency)"""
	return [source_card_data]

static func find_valid_cards(condition: String, game_context: Game) -> Array[CardData]:
	"""
	Find all cards matching the given condition.
	
	@param condition: String - Filter condition (e.g., "Creature.YouCtrl", "Card.Other+Goblin")
	@param game_context: Game - The game context
	@return: Array[CardData] - CardData instances matching the condition
	"""
	# Query GameData for cards in play
	var cards_data = game_context.game_data.get_cards_in_play()
	
	if condition == "Any":
		return cards_data
	
	var valid_targets: Array[CardData] = []
	
	for card_data in cards_data:
		if is_valid_card_data_for_condition(card_data, condition):
			valid_targets.append(card_data)
	
	return valid_targets

static func is_valid_card_data_for_condition(card_data: CardData, condition: String) -> bool:
	"""
	Check if a CardData matches the given condition string.
	
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
			
			if not _check_condition_part_data(card_data, part):
				return false
	
	return true

static func _check_condition_part_data(card_data: CardData, part: String) -> bool:
	"""Check if a CardData matches a single condition part"""
	match part:
		"Card":
			# Generic card reference, always true
			return true
		
		"Other":
			# This needs context of the source card, should be handled at ability level
			# For now, always return true and let ability level handle it
			return true
		
		"Creature":
			return card_data.hasType(CardData.CardType.CREATURE)
		
		"Spell":
			return card_data.hasType(CardData.CardType.SPELL)
		
		"YouCtrl":
			return card_data.playerControlled
		
		"OppCtrl":
			return not card_data.playerControlled
		
		_:
			# Check if it's a card type
			if CardData.isValidCardTypeString(part):
				var card_type = CardData.stringToCardType(part)
				return card_data.hasType(card_type)
			else:
				# Assume it's a subtype
				return card_data.hasSubtype(part)
	
	return false

static func filter_out_source(cards_data: Array[CardData], source_card_data: CardData) -> Array[CardData]:
	"""Remove the source card from a list of CardData (for 'Other' conditions)"""
	var filtered: Array[CardData] = []
	for card_data in cards_data:
		if card_data != source_card_data:
			filtered.append(card_data)
	
	return filtered
