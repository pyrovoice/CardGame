extends Node
class_name CardPaymentManager

## Autoload singleton for handling card payment logic (gold costs + additional costs)
## This class manages all logic related to checking if cards can be paid for and actually paying for them

# Reference to the current game instance for accessing game state
var current_game: Game = null

func set_game_context(game: Game):
	"""Set the current game context for payment operations"""
	current_game = game

func canPayCosts(costs: Array[Dictionary], source_card_data: CardData) -> bool:
	"""Check if costs can be paid - used for both card play and ability activation
	
	Args:
		costs: Array of cost dictionaries (e.g., from activation_costs or additional_costs)
		source_card_data: The card data with the costs
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
					var source_zone = current_game.game_data.get_card_zone(source_card_data)
					var is_correct_controller_zone = GameZone.is_player_zone(source_zone) if source_card_data.playerControlled else GameZone.is_opponent_zone(source_zone)
					if not GameZone.is_in_play(source_zone) or not is_correct_controller_zone:
						return false
				else:
					# Check if there are enough valid cards to sacrifice based on the filter
					var controller_filter = "YouCtrl" if source_card_data.playerControlled else "OppCtrl"
					
					# Inject controller filter into each OR branch
					var target_filter: String
					if target == "":
						target_filter = controller_filter
					else:
						# Split by "/" (OR), inject controller into each, rejoin
						var or_branches = target.split("/")
						var filtered_branches: Array[String] = []
						for branch in or_branches:
							filtered_branches.append(controller_filter + "+" + branch)
						target_filter = "/".join(filtered_branches)
					
					var valid_count = current_game._matches_card_filter(target_filter).size()
					if valid_count < count:
						print("⚠️ Not enough valid cards to sacrifice (need ", count, ", found ", valid_count, ") for filter: ", target_filter)
						return false
			
			"PayMana":
				var amount = cost.get("amount", 0)
				if current_game.game_data.player_gold.getValue() < amount:
					return false
			
			"Tap":
				var target = cost.get("target", "")
				if target == "Self":
					# Check if the card can be tapped
					if not source_card_data.can_tap():
						return false
				else:
					print("❌ Unsupported tap target: ", target)
					return false
			
			_:
				print("❌ Unknown cost type: ", cost_type)
				return false
	
	return true

func canPayCard(card_data: CardData) -> bool:
	if not card_data or not current_game:
		return false
	
	# Check casting conditions first (must be met to even consider the card castable)
	if not canMeetCastingConditions(card_data):
		return false
	
	var base_cost = card_data.goldCost
	var can_afford_base = current_game.game_data.has_gold(base_cost, card_data.playerControlled)
	
	# First check if card can be afforded at base cost
	if can_afford_base:
		# Convert additional costs to cost array format and check if they can be paid
		var cost_array = _convertAdditionalCostsToCostArray(card_data.additionalCosts, true)
		if cost_array.size() > 0:
			return canPayCosts(cost_array, card_data)
		return true
	
	# If not affordable at base cost, check if Replace can make it affordable
	# Replace is an optional alternative casting method, but only valid if at least one target makes it affordable
	if hasReplaceOption(card_data):
		# Check if any Replace target would make the cost affordable
		for cost_data in card_data.additionalCosts:
			if cost_data.get("cost_type", "") == "Replace":
				var valid_targets = getValidReplaceTargets(card_data, cost_data)
				for target_data in valid_targets:
					var replace_cost = calculateReplaceCost(card_data, target_data)
					if current_game.game_data.has_gold(replace_cost, card_data.playerControlled):
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

func payCosts(costs: Array[Dictionary], source_card_data: CardData, pre_selections: SelectionManager.CardPlaySelections = null) -> Dictionary:
	"""Determine what costs need to be paid - returns info for game.gd to execute
	
	Args:
		costs: Array of cost dictionaries to pay
		source_card_data: The card data with the costs
		pre_selections: Optional pre-selected cards (e.g., sacrifice targets) to skip user selection
	
	Returns:
		Dictionary with:
			- success: bool - whether costs can be paid
			- cards_to_sacrifice: Array[CardData] - cards that need to be sacrificed
			- gold_to_pay: int - amount of gold to spend
			- card_to_tap: CardData - card that needs to be tapped (if any)
	"""
	var result = {
		"success": false,
		"cards_to_sacrifice": [],
		"gold_to_pay": 0,
		"card_to_tap": null
	}
	
	if not current_game:
		return result
		
	for cost in costs:
		var cost_type = cost.get("type", "")
		match cost_type:
			"Sacrifice":
				var target = cost.get("target", "")
				var count = cost.get("count", 1)
				
				if target == "Self":
					print("🔥 Need to sacrifice ", source_card_data.cardName, " for cost")
					result.cards_to_sacrifice.append(source_card_data)
				else:
					# Check if we have pre-selected sacrifice targets
					if pre_selections != null and pre_selections.sacrifice_targets.size() > 0:
						print("🎯 Using pre-selected sacrifice targets (", pre_selections.sacrifice_targets.size(), " cards)")
						result.cards_to_sacrifice.append_array(pre_selections.sacrifice_targets)
					else:
						print("❌ No pre-selected sacrifice targets - game.gd should handle selection")
						return result
			
			"PayMana":
				var amount = cost.get("amount", 0)
				print("💰 Need to pay ", amount, " gold")
				result.gold_to_pay += amount
			
			"Tap":
				var target = cost.get("target", "")
				if target == "Self":
					print("🔄 Need to tap ", source_card_data.cardName)
					result.card_to_tap = source_card_data
				else:
					print("❌ Unsupported tap target: ", target)
					return result
			
			_:
				print("❌ Unknown cost type: ", cost_type)
				return result
	
	result.success = true
	return result

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

func tryPayCard(card_data: CardData, selected_additional_cards_data: Array[CardData] = []) -> Dictionary:
	"""Calculate payment requirements for a card (gold + additional costs)
	
	Returns Dictionary with:
		- success: bool
		- gold_cost: int
		- cards_to_sacrifice: Array[CardData]
	"""
	var result = {
		"success": false,
		"gold_cost": 0,
		"cards_to_sacrifice": []
	}
	
	if not card_data or not current_game:
		return result
	
	# Calculate the actual gold cost (may be reduced by Replace)
	var gold_cost = calculateActualCost(card_data, selected_additional_cards_data)
	
	# Check if we can afford it
	if not current_game.game_data.has_gold(gold_cost, card_data.playerControlled):
		var current_gold = current_game.game_data.player_gold.getValue() if card_data.playerControlled else current_game.game_data.opponent_gold.getValue()
		print("❌ Not enough gold! Need: ", gold_cost, " Have: ", current_gold)
		return result
	
	result.gold_cost = gold_cost
	result.cards_to_sacrifice = selected_additional_cards_data.duplicate()
	result.success = true
	
	return result

func calculateActualCost(card_data: CardData, selected_cards_data: Array[CardData] = []) -> int:
	"""Calculate the actual cost considering Replace reductions"""
	if not card_data:
		return 0
	
	var base_cost = card_data.goldCost
	
	# Check if Replace is being used
	var replace_target = findReplaceTarget(card_data, selected_cards_data)
	if replace_target:
		print("💰 [REPLACE COST] Calculating reduced cost with replacement: ", replace_target.cardName)
		return calculateReplaceCost(card_data, replace_target)
	
	return base_cost

func findReplaceTarget(card_data: CardData, selected_cards_data: Array[CardData]) -> CardData:
	"""Find the Replace target among selected cards"""
	if not card_data or selected_cards_data.is_empty():
		return null
	
	# Check if card has Replace option
	for cost_data in card_data.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			var valid_targets = getValidReplaceTargets(card_data, cost_data)
			
			# Find which selected card is a valid Replace target
			for selected_card_data in selected_cards_data:
				if selected_card_data in valid_targets:
					return selected_card_data
			break
	
	return null

func _get_matching_cards_in_pool(filter: String, card_pool: Array[CardData]) -> Array[CardData]:
	"""Filter a specific card pool using game's global card filter matcher."""
	var matching_cards: Array[CardData] = []
	if not current_game or card_pool.is_empty():
		return matching_cards

	for card_data in current_game._matches_card_filter(filter):
		if card_data in card_pool:
			matching_cards.append(card_data)

	return matching_cards

func isValidReplaceTarget(card: CardData, replace_target_data: CardData) -> bool:
	"""Check if a specific card is a valid Replace target for the given card"""
	if not card or not replace_target_data:
		return false
	
	# Check if card has Replace option and validate the target directly
	for cost_data in card.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			var single_target: Array[CardData] = [replace_target_data]
			
			# Check primary valid targets
			var valid_card_filter = cost_data.get("valid_card", "")
			if valid_card_filter != "" and _get_matching_cards_in_pool(valid_card_filter, single_target).size() > 0:
				return true
			
			# Check alternative valid targets
			var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
			if valid_card_alt_filter != "" and _get_matching_cards_in_pool(valid_card_alt_filter, single_target).size() > 0:
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
	# Defensive check: ensure this method is called with the correct cost type
	if cost_data.get("cost_type", "") != "SacrificePermanent":
		print("    ERROR: canSacrificePermanents called with wrong cost_type: ", cost_data.get("cost_type", ""))
		return false
	
	if not current_game:
		print("    ERROR: current_game is null")
		return false
		
	var required_count = cost_data.get("count", 1)
	var valid_card_filter = cost_data.get("valid_card", "Card")
	
	# Get all cards the player controls from GameData
	var available_cards_data: Array[CardData] = []
	if playerSide:
		available_cards_data = current_game.game_data.get_player_controlled_cards()
	else:
		available_cards_data = current_game.game_data.get_opponent_controlled_cards()
	
	# Count valid cards
	return _get_matching_cards_in_pool(valid_card_filter, available_cards_data).size() >= required_count

func canUseReplace(cost_data: Dictionary, playerSide = true) -> bool:
	"""Check if player can use Replace (has valid targets for replacement)"""
	# Defensive check: ensure this method is called with the correct cost type
	if cost_data.get("cost_type", "") != "Replace":
		print("    ERROR: canUseReplace called with wrong cost_type: ", cost_data.get("cost_type", ""))
		return false
	
	if not current_game:
		print("    ERROR: current_game is null")
		return false
	
	# Get all cards the player controls from GameData
	var available_cards_data: Array[CardData] = []
	if playerSide:
		available_cards_data = current_game.game_data.get_player_controlled_cards()
	else:
		available_cards_data = current_game.game_data.get_opponent_controlled_cards()
	
	# Check primary valid targets
	var valid_card_filter = cost_data.get("valid_card", "")
	if valid_card_filter != "" and _get_matching_cards_in_pool(valid_card_filter, available_cards_data).size() > 0:
		return true
	
	# Check alternative valid targets
	var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
	if valid_card_alt_filter != "" and _get_matching_cards_in_pool(valid_card_alt_filter, available_cards_data).size() > 0:
		return true
	
	# No valid targets found
	return false

func payAdditionalCosts(additional_costs: Array[Dictionary], selected_cards_data: Array[CardData] = []) -> Array[CardData]:
	"""Determine which cards need to be sacrificed for additional costs
	
	Returns Array[CardData] of cards to sacrifice (game.gd handles actual movement)
	"""
	var cards_to_sacrifice: Array[CardData] = []

	# selected_cards_data is assumed to contain cards for a single cost type flow:
	# either Replace targets or SacrificePermanent targets, never both.
	for cost_data in additional_costs:
		var cost_type = cost_data.get("cost_type", "")
		if cost_type == "Replace":
			for card_data in selected_cards_data:
				if card_data and card_data not in cards_to_sacrifice:
					cards_to_sacrifice.append(card_data)
		elif cost_type == "SacrificePermanent":
			var sacrifice_cards = getSacrificeCards(cost_data, selected_cards_data)
			cards_to_sacrifice.append_array(sacrifice_cards)
	
	return cards_to_sacrifice

func getSacrificeCards(cost_data: Dictionary, selected_cards_data: Array[CardData]) -> Array[CardData]:
	"""Get cards to sacrifice from selected cards"""
	var result: Array[CardData] = []
	var required_count = cost_data.get("count", 1)
	
	for card_data in selected_cards_data:
		result.append(card_data)
		if result.size() >= required_count:
			break
	
	return result

func findReplaceTargetsInCards(selected_cards_data: Array[CardData]) -> Array[CardData]:
	"""Find Replace targets among selected cards (used when we don't have the casting card context)"""
	var replace_targets: Array[CardData] = []
	
	# Look for cards that could be Replace targets
	# This is a heuristic since we don't have the casting card context here
	for card_data in selected_cards_data:
		if card_data:
			# Check if this card has the typical characteristics of a Replace target
			# (creature, reasonable cost, player controlled)
			if (card_data.hasType(CardData.CardType.CREATURE) and 
				card_data.playerControlled and 
				card_data.goldCost <= 5): # Reasonable cost range
				replace_targets.append(card_data)
	
	return replace_targets

func isCardCastable(card_data: CardData) -> bool:
	"""Check if a card can be cast (affordable including additional costs)"""
	if not card_data:
		return false
	
	# Use the same logic as canPayCard for consistency
	return canPayCard(card_data)

func isCardDataCastable(card_data: CardData) -> bool:
	"""Check if a card data can be cast (affordable including additional costs)"""
	if not card_data:
		return false
	
	# Use the same logic as canPayCardData for consistency
	return canPayCardData(card_data)

func hasReplaceOption(card_data: CardData) -> bool:
	"""Check if a card has Replace as an alternative casting option"""
	if not card_data:
		return false
	
	for cost_data in card_data.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			return canUseReplace(cost_data, card_data.playerControlled)
	
	return false

func canMeetCastingConditions(card_data: CardData) -> bool:
	"""Check if all casting conditions for the card are met
	
	Casting conditions are filter strings (e.g., "YouCtrl+Grown-up") that must be satisfied
	for the card to be castable. Unlike costs, these don't consume resources.
	"""
	if not card_data or not current_game:
		return false
	
	if not card_data.hasCastingConditions():
		return true  # No conditions means always satisfied
	
	# Check each condition - ALL must be met
	for condition in card_data.getCastingConditions():
		var matching_cards = current_game._matches_card_filter(condition)
		if matching_cards.is_empty():
			return false  # Condition not met
	
	return true  # All conditions met

func calculateReplaceCost(card_data: CardData, replacement_target_data: CardData) -> int:
	"""Calculate the final cost when using Replace with the given target"""
	if not card_data or not replacement_target_data:
		return card_data.goldCost if card_data else 0
	
	var base_cost = card_data.goldCost
	var target_cost = replacement_target_data.goldCost
	var additional_reduction = 0
	
	# Find the Replace cost data to get additional reduction
	for cost_data in card_data.additionalCosts:
		if cost_data.get("cost_type", "") == "Replace":
			# Check if this target matches the alternative criteria for extra reduction
			var valid_card_alt_filter = cost_data.get("valid_card_alt", "")
			var single_target: Array[CardData] = [replacement_target_data]
			if valid_card_alt_filter != "" and _get_matching_cards_in_pool(valid_card_alt_filter, single_target).size() > 0:
				additional_reduction = cost_data.get("add_reduction", 0)
			break
	
	var final_cost = base_cost - target_cost - additional_reduction
	return max(0, final_cost)  # Cost can't be negative

func getValidReplaceTargets(card_data: CardData, replace_cost_data: Dictionary) -> Array[CardData]:
	"""Get all valid targets for Replace mechanic using provided Replace cost data"""
	var valid_targets: Array[CardData] = []
	
	if not card_data or not current_game:
		return valid_targets
	
	# Query game_data for controlled cards
	var available_cards_data: Array[CardData] = []
	if card_data.playerControlled:
		available_cards_data = current_game.game_data.get_player_controlled_cards()
	else:
		available_cards_data = current_game.game_data.get_opponent_controlled_cards()
	
	# Add primary valid targets using unified filter
	var valid_card_filter = replace_cost_data.get("valid_card", "")
	if valid_card_filter != "":
		var primary_targets = _get_matching_cards_in_pool(valid_card_filter, available_cards_data)
		valid_targets.append_array(primary_targets)
	
	# Add alternative valid targets using unified filter
	var valid_card_alt_filter = replace_cost_data.get("valid_card_alt", "")
	if valid_card_alt_filter != "":
		var alt_targets = _get_matching_cards_in_pool(valid_card_alt_filter, available_cards_data)
		for target in alt_targets:
			if target not in valid_targets:
				valid_targets.append(target)
	
	return valid_targets
