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
	
	# Check gold cost
	var gold_cost = card.cardData.goldCost
	if not current_game.game_data.has_gold(gold_cost, card.cardData.playerControlled):
		return false
	
	# Check additional costs
	if card.cardData.hasAdditionalCosts():
		return canPayAdditionalCosts(card.cardData)
	
	return true

func canPayCardData(card_data: CardData) -> bool:
	"""Check if player can pay for the card data's cost (gold + additional costs)"""
	if not card_data or not current_game:
		return false
	
	# Check gold cost
	if not current_game.game_data.has_gold(card_data.goldCost, card_data.playerControlled):
		return false
	
	# Check additional costs
	if card_data.hasAdditionalCosts():
		return canPayAdditionalCosts(card_data)
	
	return true

func tryPayCard(card: Card, selected_additional_cards: Array[Card] = []) -> bool:
	"""Attempt to pay for a card's cost (gold + additional costs), returns true if successful"""
	if not card or not card.cardData or not current_game:
		return false
	
	# First check if we can pay all costs
	if not canPayCard(card):
		return false
	
	var gold_cost = card.cardData.goldCost
	print("Trying to pay ", gold_cost, " gold for ", card.cardData.cardName)
	
	# Pay gold cost first
	if not current_game.game_data.spend_gold(gold_cost, card.cardData.playerControlled):
		print("Failed to pay gold cost!")
		return false
	
	print("Successfully paid ", gold_cost, " gold. Remaining gold: ", current_game.game_data.player_gold.value)
	
	# Pay additional costs
	if card.cardData.hasAdditionalCosts():
		if not await payAdditionalCosts(card.cardData.getAdditionalCosts(), selected_additional_cards):
			print("Failed to pay additional costs!")
			# Refund the gold since additional costs failed
			current_game.game_data.add_gold(gold_cost)
			return false
		print("Successfully paid additional costs")
	
	return true

func canPayAdditionalCosts(cardData: CardData) -> bool:
	var additional_costs = cardData.additionalCosts
	for i in range(additional_costs.size()):
		var cost_data = additional_costs[i]
		var can_pay = canPaySingleAdditionalCost(cost_data, cardData.playerControlled)
		if not can_pay:
			return false
	
	return true

func canPaySingleAdditionalCost(cost_data: Dictionary, playerSide = true) -> bool:
	"""Check if player can pay a single additional cost"""
	var cost_type = cost_data.get("cost_type", "")
	
	match cost_type:
		"SacrificePermanent":
			return canSacrificePermanents(cost_data, playerSide)
		_:
			print("  Unknown additional cost type: ", cost_type)
			return false

func canSacrificePermanents(cost_data: Dictionary, playerSide = true) -> bool:
	"""Check if player can sacrifice the required permanents"""
	if not current_game:
		print("    ERROR: current_game is null")
		return false
		
	var required_count = cost_data.get("count", 1)
	var valid_card_filter = cost_data.get("valid_card", "Card")
	
	# Get all cards the player controls that match the filter
	var available_cards = current_game.getControllerCards(playerSide)
	var valid_cards = filterCardsByValidCard(available_cards, valid_card_filter)
	# Check if we have enough valid cards to sacrifice
	var can_sacrifice = valid_cards.size() >= required_count
	return can_sacrifice

func payAdditionalCosts(additional_costs: Array[Dictionary], selected_cards: Array[Card] = []) -> bool:
	"""Actually pay all additional costs using selected cards"""
	for cost_data in additional_costs:
		if not await paySingleAdditionalCost(cost_data, selected_cards):
			return false
	return true

func paySingleAdditionalCost(cost_data: Dictionary, selected_cards: Array[Card] = []) -> bool:
	"""Pay a single additional cost using selected cards"""
	var cost_type = cost_data.get("cost_type", "")
	
	match cost_type:
		"SacrificePermanent":
			return await sacrificePermanents(cost_data, selected_cards)
		_:
			print("Unknown additional cost type: ", cost_type)
			return false

func sacrificePermanents(cost_data: Dictionary, selected_cards: Array[Card] = []) -> bool:
	"""Sacrifice the required permanents using selected cards or auto-selecting if none provided"""
	if not current_game:
		return false
		
	var required_count = cost_data.get("count", 1)
	var valid_card_filter = cost_data.get("valid_card", "Card")
	
	var cards_to_sacrifice: Array[Card] = []
	
	if selected_cards.is_empty():
		# Auto-select cards (fallback behavior)
		print("No cards provided for sacrifice, auto-selecting...")
		var available_cards = current_game.getPlayerControlledCards()
		var valid_cards = filterCardsByValidCard(available_cards, valid_card_filter)
		
		if valid_cards.size() < required_count:
			print("Not enough valid cards to sacrifice! Need: ", required_count, ", Have: ", valid_cards.size())
			return false
		
		# Take the first N valid cards
		for i in range(required_count):
			cards_to_sacrifice.append(valid_cards[i])
	else:
		# Use player-selected cards
		print("Using player-selected cards for sacrifice...")
		
		# Validate that the selected cards are valid for this sacrifice
		var valid_selected_cards = filterCardsByValidCard(selected_cards, valid_card_filter)
		
		if valid_selected_cards.size() < required_count:
			print("Not enough valid selected cards! Need: ", required_count, ", Have: ", valid_selected_cards.size())
			return false
		
		# Use the first N valid selected cards
		for i in range(required_count):
			cards_to_sacrifice.append(valid_selected_cards[i])
	
	# Perform the sacrifice
	if cards_to_sacrifice.size() > 0:
		print("Sacrificing ", cards_to_sacrifice.size(), " cards matching '", valid_card_filter, "':")
		
		# Capture card names BEFORE sacrificing to avoid accessing freed objects
		var card_names = []
		for card_to_sacrifice in cards_to_sacrifice:
			if card_to_sacrifice and card_to_sacrifice.cardData:
				card_names.append(card_to_sacrifice.cardData.cardName)
		
		# Use the game's putInOwnerGraveyard function which handles animations
		await current_game.putInOwnerGraveyard(cards_to_sacrifice)
	
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
