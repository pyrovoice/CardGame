extends Node
class_name GameHelper

## Utility class for common game operations and card filtering
## Provides centralized filtering logic to avoid code duplication across managers

## Filter cards by complex criteria with AND (+) and OR (/) logic
## Example: "Card.YouCtrl+Creature+Cost.1" matches your 1-cost creatures
## Example: "Creature/Spell" matches creatures OR spells
static func filterCardsByParameters(cards: Array[Card], filter: String, game: Game) -> Array[Card]:
	"""Filter cards by complex criteria using AND (+) and OR (/) logic"""
	if filter == "Any":
		return cards
	
	var matching_cards: Array[Card] = []
	
	# Handle OR logic first - split by '/'
	var or_parts = filter.split("/")
	
	for card in cards:
		var matches_any_or_part = false
		for or_part in or_parts:
			# For each OR part, parse criteria and check if card matches
			var criteria = parseCriteria(or_part)
			if matchesAllCriteria(card, criteria, game):
				matches_any_or_part = true
				break
		
		if matches_any_or_part:
			matching_cards.append(card)
	
	return matching_cards

static func parseCriteria(filter_str: String) -> Dictionary:
	"""Parse a filter string with AND logic (+) into structured criteria"""
	var criteria = {
		"controller": "",  # "YouCtrl", "OppCtrl", or ""
		"card_types": [],  # Array of card types: ["Creature", "Spell", etc.]
		"subtypes": [],    # Array of subtypes: ["Goblin", "Human", etc.]
		"cost": -1,        # Exact cost, -1 = any
		"cost_min": -1,    # Minimum cost, -1 = no min
		"cost_max": -1,    # Maximum cost, -1 = no max
		"power": -1,       # Exact power, -1 = any
		"power_min": -1,   # Minimum power, -1 = no min
		"power_max": -1,   # Maximum power, -1 = no max
		"token": ""        # "Token", "NonToken", or ""
	}
	
	# Split by '+' for AND logic
	var parts = filter_str.split("+")
	for part in parts:
		process_filter_part(part, criteria)
	
	return criteria

static func process_filter_part(part: String, criteria: Dictionary) -> void:
	"""Process a single filter part and update criteria dictionary"""
	if part == "Card.YouCtrl":
		criteria.controller = "YouCtrl"
	elif part == "Card.OppCtrl":
		criteria.controller = "OppCtrl"
	elif part == "YouCtrl":
		criteria.controller = "YouCtrl"
	elif part == "OppCtrl":
		criteria.controller = "OppCtrl"
	elif part == "Token":
		criteria.token = "Token"
	elif part == "NonToken":
		criteria.token = "NonToken"
	elif part.begins_with("Cost."):
		criteria.cost = int(part.substr(5))
	elif part.begins_with("MinCost."):
		criteria.cost_min = int(part.substr(8))
	elif part.begins_with("MaxCost."):
		criteria.cost_max = int(part.substr(8))
	elif part.begins_with("Power."):
		criteria.power = int(part.substr(6))
	elif part.begins_with("MinPower."):
		criteria.power_min = int(part.substr(9))
	elif part.begins_with("MaxPower."):
		criteria.power_max = int(part.substr(9))
	elif part in ["Creature", "Spell", "Land", "Artifact", "Enchantment"]:
		criteria.card_types.append(part)
	else:
		# Treat as subtype (Goblin, Grown-up, etc.)
		criteria.subtypes.append(part)

static func matchesAllCriteria(card: Card, criteria: Dictionary, game: Game) -> bool:
	"""Check if a card matches all the parsed criteria"""
	var card_data = card.cardData
	
	# Check controller
	if criteria.controller == "YouCtrl" and not card_data.playerControlled:
		return false
	elif criteria.controller == "OppCtrl" and card_data.playerControlled:
		return false
	
	# Check token status
	if criteria.token == "Token" and not card.isToken:
		return false
	elif criteria.token == "NonToken" and card.isToken:
		return false
	
	# Check card types
	if not criteria.card_types.is_empty():
		var has_required_type = false
		for required_type in criteria.card_types:
			# Use centralized conversion method
			if CardData.isValidCardTypeString(required_type):
				var card_type = CardData.stringToCardType(required_type)
				if card_data.hasType(card_type):
					has_required_type = true
					break
		if not has_required_type:
			return false
	
	# Check subtypes
	if not criteria.subtypes.is_empty():
		var has_required_subtype = false
		for required_subtype in criteria.subtypes:
			if required_subtype in card_data.subtypes:
				has_required_subtype = true
				break
		if not has_required_subtype:
			return false
	
	# Check exact cost
	if criteria.cost >= 0 and card_data.goldCost != criteria.cost:
		return false
	
	# Check cost range
	if criteria.cost_min >= 0 and card_data.goldCost < criteria.cost_min:
		return false
	if criteria.cost_max >= 0 and card_data.goldCost > criteria.cost_max:
		return false
	
	# Check exact power
	if criteria.power >= 0 and card_data.power != criteria.power:
		return false
	
	# Check power range
	if criteria.power_min >= 0 and card_data.power < criteria.power_min:
		return false
	if criteria.power_max >= 0 and card_data.power > criteria.power_max:
		return false
	
	return true
