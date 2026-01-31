extends Node
class_name CardPaymentManager

## Autoload singleton for handling card payment logic (gold costs + additional costs)
## This class manages all logic related to checking if cards can be paid for and actually paying for them

# Reference to the current game instance for accessing game state
var current_game: Game = null

func set_game_context(game: Game):
	"""Set the current game context for payment operations"""
	current_game = game

func canPayCosts(costs: Array[Dictionary], source_card: Card) -> bool:
	"""Check if costs can be paid - used for both card play and ability activation
	
	Args:
		costs: Array of cost dictionaries (e.g., from activation_costs or additional_costs)
		source_card: The card with the costs
	"""
	if not current_game:
		return false
		
	for cost in costs:
		var cost_type = cost.get("type", "")
		match cost_type:
			"Sacrifice":
				var target = cost.get("target", "")
				var count = cost.get("count", 1)
				
				if target == "Self":
					# Can always sacrifice self if the card is in play
					var source_zone = current_game.getCardZone(source_card)
					if source_zone != GameZone.e.PLAYER_BASE and source_zone != GameZone.e.COMBAT_ZONE:
						return false
				else:
					# Check if there are enough valid cards to sacrifice based on the filter
					var all_cards = current_game.getAllCardsInPlay()
					var valid_cards = GameHelper.filterCardsByParameters(all_cards, target, current_game)
					if valid_cards.size() < count:
						print("⚠️ Not enough valid cards to sacrifice (need ", count, ", found ", valid_cards.size(), ") for filter: ", target)
						return false
			
			"PayMana":
				var amount = cost.get("amount", 0)
				if current_game.game_data.player_gold.getValue() < amount:
					return false
			
			"Tap":
				var target = cost.get("target", "")
				if target == "Self":
					# Check if the card can be tapped
					if not source_card.cardData.can_tap():
						return false
				else:
					print("❌ Unsupported tap target: ", target)
					return false
			
			_:
				print("❌ Unknown cost type: ", cost_type)
				return false
	
	return true

func canPayCard(card: Card) -> bool:
	if not card or not card.cardData or not current_game:
		return false
	
	var base_cost = card.cardData.goldCost
	var can_afford_base = current_game.game_data.has_gold(base_cost, card.cardData.playerControlled)
	
	# First check if card can be afforded at base cost
	if can_afford_base:
		# Convert additional costs to cost array format and check if they can be paid
		var cost_array = _convertAdditionalCostsToCostArray(card.cardData.additionalCosts, true)
		if cost_array.size() > 0:
			return canPayCosts(cost_array, card)
		return true
	
	# If not affordable at base cost, check if Replace can make it affordable
	# Replace is an optional alternative casting method, but only valid if at least one target makes it affordable
	if hasReplaceOption(card):
		# Check if any Replace target would make the cost affordable
		for cost_data in card.cardData.additionalCosts:
			if cost_data.get("cost_type", "") == "Replace":
				var valid_targets = getValidReplaceTargets(card, cost_data)
				for target in valid_targets:
					var replace_cost = calculateReplaceCost(card, target)
					if current_game.game_data.has_gold(replace_cost, card.cardData.playerControlled):
						# At least one Replace target makes it affordable
						return true
				break
	
	return false

func _convertAdditionalCostsToCostArray(additional_costs: Array[Dictionary], skip_replace: bool = false) -> Array[Dictionary]:
	"""Convert additional costs (SacrificePermanent, Replace) to unified cost array format"""
	var costs: Array[Dictionary] = []
	
	for cost_data in additional_costs:
		var cost_type = cost_data.get("cost_type", "")
		
		# Skip Replace costs if requested (they're optional alternatives)
		if skip_replace and cost_type == "Replace":
			continue
		
		match cost_type:
			"SacrificePermanent":
				var sacrifice_cost = {
					"type": "Sacrifice",
					"target": cost_data.get("valid_card", "Card"),
					"count": cost_data.get("count", 1)
				}
				costs.append(sacrifice_cost)
			# Add more cost type conversions as needed
	
	return costs

func payCosts(costs: Array[Dictionary], source_card: Card, pre_selections: SelectionManager.CardPlaySelections = null) -> bool:
	"""Pay costs - used for both card play and ability activation
	
	Args:
		costs: Array of cost dictionaries to pay
		source_card: The card with the costs
		pre_selections: Optional pre-selected cards (e.g., sacrifice targets) to skip user selection
	"""
	if not current_game:
		return false
		
	for cost in costs:
		var cost_type = cost.get("type", "")
		match cost_type:
			"Sacrifice":
				var target = cost.get("target", "")
				var count = cost.get("count", 1)
				
				if target == "Self":
					print("🔥 Sacrificing ", source_card.cardData.cardName, " for cost")
					# Move the card to graveyard
					var dest_zone = current_game.graveyard if source_card.cardData.playerOwned else current_game.graveyard_opponent
					await current_game.execute_move_card(source_card, dest_zone)
				else:
					# Check if we have pre-selected sacrifice targets
					var selected_cards: Array[Card] = []
					
					if pre_selections != null and pre_selections.sacrifice_targets.size() > 0:
						# Use pre-selected cards
						print("🎯 Using pre-selected sacrifice targets (", pre_selections.sacrifice_targets.size(), " cards)")
						selected_cards = pre_selections.sacrifice_targets
					else:
						# Need to select card(s) to sacrifice based on the filter
						print("🔍 Selecting ", count, " card(s) to sacrifice with filter: ", target)
						var all_cards = current_game.getAllCardsInPlay()
						var valid_cards = GameHelper.filterCardsByParameters(all_cards, target, current_game)
						if valid_cards.size() < count:
							print("❌ Not enough valid cards to sacrifice")
							return false
						
						# Use selection manager to let player choose which card(s) to sacrifice
						selected_cards = await current_game.start_card_selection(
							{"filter": target, "count": count},
							valid_cards,
							"sacrifice_for_cost",
							source_card
						)
					
					if selected_cards.size() < count:
						print("❌ Not enough cards selected for sacrifice (need ", count, ", got ", selected_cards.size(), ")")
						return false
					
					# Sacrifice all selected cards
					for card_to_sacrifice in selected_cards:
						print("🔥 Sacrificing ", card_to_sacrifice.cardData.cardName, " for cost")
						var dest_zone = current_game.graveyard if card_to_sacrifice.cardData.playerOwned else current_game.graveyard_opponent
						await current_game.execute_move_card(card_to_sacrifice, dest_zone)
			
			"PayMana":
				var amount = cost.get("amount", 0)
				print("💰 Paying ", amount, " mana")
				var current_gold = current_game.game_data.player_gold.getValue()
				current_game.game_data.player_gold.setValue(current_gold - amount)
			
			"Tap":
				var target = cost.get("target", "")
				if target == "Self":
					print("🔄 Tapping ", source_card.cardData.cardName)
					source_card.cardData.tap()
				else:
					print("❌ Unsupported tap target: ", target)
					return false
			
			_:
				print("❌ Unknown cost type: ", cost_type)
				return false
	
	# Small delay to show the cost payment
	await current_game.get_tree().process_frame
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
	
	# Calculate the actual gold cost (may be reduced by Replace)
	var gold_cost = calculateActualCost(card, selected_additional_cards)
	
	# Check if we can pay all costs with the actual cost
	if not current_game.game_data.has_gold(gold_cost, card.cardData.playerControlled):
		print("❌ Not enough gold! Need: ", gold_cost, " Have: ", current_game.game_data.get_gold(card.cardData.playerControlled))
		return false
	
	# Pay gold cost first
	if not current_game.game_data.spend_gold(gold_cost, card.cardData.playerControlled):
		print("Failed to pay gold cost!")
		return false
	
	
	# Pay additional costs using payAdditionalCosts (handles Replace target logic)
	if card.cardData.hasAdditionalCosts() or selected_additional_cards.size() > 0:
		if not await payAdditionalCosts(card.cardData.getAdditionalCosts(), selected_additional_cards):
			print("Failed to pay additional costs!")
			# Refund the gold since additional costs failed
			current_game.game_data.add_gold(gold_cost)
			return false
		print("Successfully paid additional costs")
	
	return true

func calculateActualCost(card: Card, selected_cards: Array[Card] = []) -> int:
	"""Calculate the actual cost considering Replace reductions"""
	if not card or not card.cardData:
		return 0
	
	var base_cost = card.cardData.goldCost
	
	# Check if Replace is being used
	var replace_target = findReplaceTarget(card, selected_cards)
	if replace_target:
		print("💰 [REPLACE COST] Calculating reduced cost with replacement: ", replace_target.cardData.cardName)
		return calculateReplaceCost(card, replace_target)
	
	return base_cost

func findReplaceTarget(card: Card, selected_cards: Array[Card]) -> Card:
	"""Find the Replace target among selected cards"""
	if not card or not card.cardData or selected_cards.is_empty():
		return null
	
	# Check if card has Replace option
	for cost_data in card.cardData.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			var valid_targets = getValidReplaceTargets(card, cost_data)
			
			# Find which selected card is a valid Replace target
			for selected_card in selected_cards:
				if selected_card in valid_targets:
					return selected_card
			break
	
	return null

func isValidReplaceTarget(card: Card, replace_target: Card) -> bool:
	"""Check if a specific card is a valid Replace target for the given card"""
	if not card or not card.cardData or not replace_target or not replace_target.cardData:
		return false
	
	# Check if card has Replace option and validate the target directly
	for cost_data in card.cardData.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			# Check primary valid targets
			var valid_card_filter = cost_data.get("valid_card", "")
			if valid_card_filter != "":
				var targets: Array[Card] = [replace_target]
				var primary_valid = filterCardsByParameters(targets, valid_card_filter, current_game)
				if primary_valid.size() > 0:
					return true
			
			# Check alternative valid targets
			var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
			if valid_card_alt_filter != "":
				var targets: Array[Card] = [replace_target]
				var alt_valid = filterCardsByParameters(targets, valid_card_alt_filter, current_game)
				if alt_valid.size() > 0:
					return true
			
			break
	
	return false

func canPayAdditionalCosts(cardData: CardData) -> bool:
	var additional_costs = cardData.additionalCosts
	for i in range(additional_costs.size()):
		var cost_data = additional_costs[i]
		var can_pay = canPaySingleAdditionalCost(cost_data, cardData.playerControlled)
		if not can_pay:
			return false
	
	return true

func canPayNonReplaceAdditionalCosts(cardData: CardData) -> bool:
	"""Check if player can pay additional costs, excluding Replace costs which are optional alternatives"""
	var additional_costs = cardData.additionalCosts
	for i in range(additional_costs.size()):
		var cost_data = additional_costs[i]
		var cost_type = cost_data.get("cost_type", "")
		
		# Skip Replace costs - they're optional alternatives, not required costs
		if cost_type == "Replace":
			continue
			
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
		"Replace":
			return canUseReplace(cost_data, playerSide)
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
	var valid_cards = filterCardsByParameters(available_cards, valid_card_filter, current_game)
	# Check if we have enough valid cards to sacrifice
	var can_sacrifice = valid_cards.size() >= required_count
	return can_sacrifice

func canUseReplace(cost_data: Dictionary, playerSide = true) -> bool:
	"""Check if player can use Replace (has valid targets for replacement)"""
	if not current_game:
		print("    ERROR: current_game is null")
		return false
	
	# Get all cards the player controls
	var available_cards = current_game.getControllerCards(playerSide)
	
	# Check primary valid targets
	var valid_card_filter = cost_data.get("valid_card", "")
	if valid_card_filter != "":
		var valid_primary = filterCardsByParameters(available_cards, valid_card_filter, current_game)
		if valid_primary.size() > 0:
			return true
	
	# Check alternative valid targets
	var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
	if valid_card_alt_filter != "":
		var valid_alt = filterCardsByParameters(available_cards, valid_card_alt_filter, current_game)
		if valid_alt.size() > 0:
			return true
	
	# No valid targets found
	return false

func payAdditionalCosts(additional_costs: Array[Dictionary], selected_cards: Array[Card] = []) -> bool:
	"""Actually pay all additional costs using selected cards"""
	# Note: This method handles both sacrifice targets and Replace targets
	# We need to properly identify which cards are for which purpose
	
	# Find Replace targets based on the actual Replace cost data
	var replace_targets: Array[Card] = []
	var sacrifice_cards: Array[Card] = []
	
	# Check if we have Replace costs to identify Replace targets
	var has_replace_cost = false
	for cost_data in additional_costs:
		if cost_data.get("cost_type", "") == "Replace":
			has_replace_cost = true
			break
	
	if has_replace_cost:
		# Use the more accurate method to find Replace targets
		replace_targets = findActualReplaceTargets(additional_costs, selected_cards)
	
	# Remaining cards are for sacrifice costs
	for card in selected_cards:
		if not (card in replace_targets):
			sacrifice_cards.append(card)
	
	# Sacrifice Replace targets first
	for replace_target in replace_targets:
		var dest_zone = current_game.graveyard if replace_target.cardData.playerOwned else current_game.graveyard_opponent
		await current_game.execute_move_card(replace_target, dest_zone)
	
	# Process regular additional costs (like SacrificePermanent) with remaining cards
	for cost_data in additional_costs:
		var cost_type = cost_data.get("cost_type", "")
		if cost_type == "Replace":
			continue # Skip Replace costs - handled above
			
		if not await paySingleAdditionalCost(cost_data, sacrifice_cards):
			return false
	
	return true

func findActualReplaceTargets(additional_costs: Array[Dictionary], selected_cards: Array[Card]) -> Array[Card]:
	"""Find actual Replace targets by checking against Replace cost criteria"""
	var replace_targets: Array[Card] = []
	
	for cost_data in additional_costs:
		if cost_data.get("cost_type", "") == "Replace":
			# Check each selected card against Replace criteria
			var valid_card_filter = cost_data.get("valid_card", "")
			var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
			
			for card in selected_cards:
				if card and card.cardData:
					# Check against primary criteria
					if valid_card_filter != "":
						var targets: Array[Card] = [card]
						var primary_valid = filterCardsByParameters(targets, valid_card_filter, current_game)
						if primary_valid.size() > 0:
							replace_targets.append(card)
							continue
					
					# Check against alternative criteria
					if valid_card_alt_filter != "":
						var targets: Array[Card] = [card]
						var alt_valid = filterCardsByParameters(targets, valid_card_alt_filter, current_game)
						if alt_valid.size() > 0:
							replace_targets.append(card)
			break # Only one Replace cost per card
	
	return replace_targets

func findReplaceTargetsInCards(selected_cards: Array[Card]) -> Array[Card]:
	"""Find Replace targets among selected cards (used when we don't have the casting card context)"""
	var replace_targets: Array[Card] = []
	
	# Look for cards that could be Replace targets
	# This is a heuristic since we don't have the casting card context here
	for card in selected_cards:
		if card and card.cardData:
			# Check if this card has the typical characteristics of a Replace target
			# (creature, reasonable cost, player controlled)
			if (card.cardData.hasType(CardData.CardType.CREATURE) and 
				card.cardData.playerControlled and 
				card.cardData.goldCost <= 5): # Reasonable cost range
				replace_targets.append(card)
	
	return replace_targets

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
		var available_cards = current_game.getControllerCards(true) # true for player controlled
		var valid_cards = filterCardsByParameters(available_cards, valid_card_filter, current_game)
		
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
		var valid_selected_cards = filterCardsByParameters(selected_cards, valid_card_filter, current_game)
		
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
		
		# Move each card to graveyard using execute_move_card
		for card_to_sacrifice in cards_to_sacrifice:
			var dest_zone = current_game.graveyard if card_to_sacrifice.cardData.playerOwned else current_game.graveyard_opponent
			await current_game.execute_move_card(card_to_sacrifice, dest_zone)
	
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

func hasReplaceOption(card: Card) -> bool:
	"""Check if a card has Replace as an alternative casting option"""
	if not card or not card.cardData:
		return false
	
	for cost_data in card.cardData.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			return canUseReplace(cost_data, card.cardData.playerControlled)
	
	return false

func calculateReplaceCost(card: Card, replacement_target: Card) -> int:
	"""Calculate the final cost when using Replace with the given target"""
	if not card or not card.cardData or not replacement_target or not replacement_target.cardData:
		return card.cardData.goldCost if card and card.cardData else 0
	
	var base_cost = card.cardData.goldCost
	var target_cost = replacement_target.cardData.goldCost
	var additional_reduction = 0
	
	# Find the Replace cost data to get additional reduction
	for cost_data in card.cardData.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			# Check if this target matches the alternative criteria for extra reduction
			var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
			if valid_card_alt_filter != "":
				var targets: Array[Card] = [replacement_target]
				var alt_valid = filterCardsByParameters(targets, valid_card_alt_filter, current_game)
				if alt_valid.size() > 0:
					additional_reduction = cost_data.get("add_reduction", 0)
			break
	
	var final_cost = base_cost - target_cost - additional_reduction
	return max(0, final_cost)  # Cost can't be negative

func getValidReplaceTargets(card: Card, replace_cost_data: Dictionary) -> Array[Card]:
	"""Get all valid targets for Replace mechanic using provided Replace cost data"""
	var valid_targets: Array[Card] = []
	
	if not card or not card.cardData or not current_game:
		return valid_targets
	
	var available_cards = current_game.getControllerCards(card.cardData.playerControlled)
	
	# Add primary valid targets
	var valid_card_filter = replace_cost_data.get("valid_card", "")
	if valid_card_filter != "":
		var primary_valid = filterCardsByParameters(available_cards, valid_card_filter, current_game)
		valid_targets.append_array(primary_valid)
	
	# Add alternative valid targets
	var valid_card_alt_filter = replace_cost_data.get("valid_card_alt", "")
	if valid_card_alt_filter != "":
		var alt_valid = filterCardsByParameters(available_cards, valid_card_alt_filter, current_game)
		valid_targets.append_array(alt_valid)
	
	return valid_targets


func filterCardsByParameters(cards: Array[Card], filter_string: String, game: Game) -> Array[Card]:
	"""Universal card filtering method - now delegates to GameUtility for consistency"""
	return GameUtility.filterCardsByParameters(cards, filter_string, game)
