extends Node
class_name CardPaymentManager

## Autoload singleton for handling card payment logic (gold costs + additional costs)
## This class manages all logic related to checking if cards can be paid for and actually paying for them

# Reference to the current game instance for accessing game state
var current_game: Game = null

func set_game_context(game: Game):
	"""Set the current game context for payment operations"""
	current_game = game

func canPayCard(card: Card) -> bool:
	"""Check if player can pay for the card's cost (gold + additional costs)"""
	if not card or not card.cardData or not current_game:
		return false
	
	# Check gold cost
	var gold_cost = card.cardData.goldCost
	if not current_game.game_data.has_gold(gold_cost):
		return false
	
	# Check additional costs
	if card.cardData.hasAdditionalCosts():
		return canPayAdditionalCosts(card.cardData.getAdditionalCosts())
	
	return true

func canPayCardData(card_data: CardData) -> bool:
	"""Check if player can pay for the card data's cost (gold + additional costs)"""
	if not card_data or not current_game:
		return false
	
	# Check gold cost
	if not current_game.game_data.has_gold(card_data.goldCost):
		return false
	
	# Check additional costs
	if card_data.hasAdditionalCosts():
		return canPayAdditionalCosts(card_data.getAdditionalCosts())
	
	return true

func tryPayCard(card: Card) -> bool:
	"""Attempt to pay for a card's cost (gold + additional costs), returns true if successful"""
	if not card or not card.cardData or not current_game:
		return false
	
	# First check if we can pay all costs
	if not canPayCard(card):
		return false
	
	var gold_cost = card.cardData.goldCost
	print("Trying to pay ", gold_cost, " gold for ", card.cardData.cardName)
	
	# Pay gold cost first
	if not current_game.game_data.spend_gold(gold_cost):
		print("Failed to pay gold cost!")
		return false
	
	print("Successfully paid ", gold_cost, " gold. Remaining gold: ", current_game.game_data.player_gold.value)
	
	# Pay additional costs
	if card.cardData.hasAdditionalCosts():
		if not payAdditionalCosts(card.cardData.getAdditionalCosts()):
			print("Failed to pay additional costs!")
			# Refund the gold since additional costs failed
			current_game.game_data.add_gold(gold_cost)
			return false
		print("Successfully paid additional costs")
	
	return true

func canPayAdditionalCosts(additional_costs: Array[Dictionary]) -> bool:
	"""Check if player can pay all additional costs"""
	print("=== Checking Additional Costs ===")
	print("Number of additional costs: ", additional_costs.size())
	
	for i in range(additional_costs.size()):
		var cost_data = additional_costs[i]
		print("Cost ", i, ": ", cost_data)
		var can_pay = canPaySingleAdditionalCost(cost_data)
		print("Can pay cost ", i, ": ", can_pay)
		if not can_pay:
			print("=== Additional Costs Check FAILED ===")
			return false
	
	print("=== Additional Costs Check PASSED ===")
	return true

func canPaySingleAdditionalCost(cost_data: Dictionary) -> bool:
	"""Check if player can pay a single additional cost"""
	var cost_type = cost_data.get("cost_type", "")
	print("  Checking single cost type: ", cost_type)
	
	match cost_type:
		"SacrificePermanent":
			return canSacrificePermanents(cost_data)
		_:
			print("  Unknown additional cost type: ", cost_type)
			return false

func canSacrificePermanents(cost_data: Dictionary) -> bool:
	"""Check if player can sacrifice the required permanents"""
	print("    Checking sacrifice requirement...")
	if not current_game:
		print("    ERROR: current_game is null")
		return false
		
	var required_count = cost_data.get("count", 1)
	var valid_card_filter = cost_data.get("valid_card", "Card")
	print("    Required count: ", required_count)
	print("    Valid card filter: ", valid_card_filter)
	
	# Get all cards the player controls that match the filter
	var available_cards = getPlayerControlledCards()
	print("    Available cards player controls: ", available_cards.size())
	for card in available_cards:
		if card is Card and card.cardData:
			print("      - ", card.cardData.cardName, " (Types: ", card.cardData.types, ")")
	
	var valid_cards = filterCardsByValidCard(available_cards, valid_card_filter)
	print("    Valid cards after filtering: ", valid_cards.size())
	for card in valid_cards:
		if card is Card and card.cardData:
			print("      - ", card.cardData.cardName)
	
	# Check if we have enough valid cards to sacrifice
	var can_sacrifice = valid_cards.size() >= required_count
	print("    Can sacrifice required cards: ", can_sacrifice, " (", valid_cards.size(), " >= ", required_count, ")")
	return can_sacrifice

func payAdditionalCosts(additional_costs: Array[Dictionary]) -> bool:
	"""Actually pay all additional costs"""
	for cost_data in additional_costs:
		if not paySingleAdditionalCost(cost_data):
			return false
	return true

func paySingleAdditionalCost(cost_data: Dictionary) -> bool:
	"""Pay a single additional cost"""
	var cost_type = cost_data.get("cost_type", "")
	
	match cost_type:
		"SacrificePermanent":
			return sacrificePermanents(cost_data)
		_:
			print("Unknown additional cost type: ", cost_type)
			return false

func sacrificePermanents(cost_data: Dictionary) -> bool:
	"""Sacrifice the required permanents"""
	if not current_game:
		return false
		
	var required_count = cost_data.get("count", 1)
	var valid_card_filter = cost_data.get("valid_card", "Card")
	
	# Get all cards the player controls that match the filter
	var available_cards = getPlayerControlledCards()
	var valid_cards = filterCardsByValidCard(available_cards, valid_card_filter)
	
	if valid_cards.size() < required_count:
		print("Not enough valid cards to sacrifice! Need: ", required_count, ", Have: ", valid_cards.size())
		return false
	
	# For now, automatically sacrifice the first N valid cards
	# TODO: In a full implementation, you'd want to let the player choose which cards to sacrifice
	print("Sacrificing ", required_count, " cards matching '", valid_card_filter, "':")
	for i in range(required_count):
		var card_to_sacrifice = valid_cards[i]
		print("  - Sacrificing: ", card_to_sacrifice.cardData.cardName)
		current_game.putInOwnerGraveyard(card_to_sacrifice)
	
	return true

func isCardCastable(card: Card) -> bool:
	"""Check if a card can be cast (affordable including additional costs)"""
	if not card or not card.cardData:
		return false
	
	# Use the same logic as canPayCard for consistency
	return canPayCard(card)

func isCardDataCastable(card_data: CardData) -> bool:
	"""Check if a card data can be cast (affordable including additional costs)"""
	if not card_data:
		return false
	
	# Use the same logic as canPayCardData for consistency
	return canPayCardData(card_data)

func getPlayerControlledCards() -> Array[Card]:
	"""Get all cards the player currently controls (in play)"""
	print("      Getting player controlled cards...")
	if not current_game:
		print("      ERROR: current_game is null")
		return []
		
	var controlled_cards: Array[Card] = []
	
	# Add cards from player base
	var base_cards = current_game.player_base.getCards()
	print("      Cards in player base: ", base_cards.size())
	controlled_cards.append_array(base_cards)
	
	# Add cards from combat zones (ally side only)
	for combat_zone in current_game.combatZones:
		for ally_spot in combat_zone.allySpots:
			var card = ally_spot.getCard()
			if card != null:
				print("      Card in combat zone: ", card.cardData.cardName)
				controlled_cards.append(card)
	
	print("      Total controlled cards: ", controlled_cards.size())
	return controlled_cards

func filterCardsByValidCard(cards: Array[Card], valid_card_filter: String) -> Array[Card]:
	"""Filter cards based on ValidCard criteria (e.g., 'Card.YouCtrl+Goblin')"""
	var valid_cards: Array[Card] = []
	
	# Parse the filter string
	var filter_parts = valid_card_filter.split("+")
	var required_subtypes: Array[String] = []
	var has_you_ctrl = false
	
	for part in filter_parts:
		if part.contains("YouCtrl"):
			has_you_ctrl = true
		elif part != "Card":
			required_subtypes.append(part)
	
	# Filter cards based on criteria
	for card in cards:
		if not card or not card.cardData:
			continue
		
		# If YouCtrl is required, this function already handles player-controlled cards
		# so we don't need to check it again
		
		# Check subtypes if any are required
		var matches_subtypes = true
		if not required_subtypes.is_empty():
			matches_subtypes = false
			for required_subtype in required_subtypes:
				if required_subtype in card.cardData.subtypes:
					matches_subtypes = true
					break
		
		if matches_subtypes:
			valid_cards.append(card)
	
	return valid_cards
