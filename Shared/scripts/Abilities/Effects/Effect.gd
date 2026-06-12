extends RefCounted
class_name Effect

## Base class for all ability effects
## Each effect type should extend this and implement execute()

## Execute the effect
## @param parameters: Dictionary - Effect-specific parameters
## @param source_card_data: CardData - The card that is the source of this effect
## @param game_context: Game - The game context for accessing game state
## @return: void (use await if the effect is async)
func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	push_error("Effect.execute() must be implemented by subclass")
	pass

## Validate that required parameters are present
## @param parameters: Dictionary - Effect parameters to validate
## @return: bool - True if parameters are valid
func validate_parameters(parameters: Dictionary) -> bool:
	# Base implementation - override in subclasses for specific validation
	return true

## Get a human-readable description of this effect
## @param parameters: Dictionary - Effect parameters
## @return: String - Description of the effect
func get_description(parameters: Dictionary) -> String:
	return "Generic effect"

## Check if an effect requires selecting a target based on its parameters
## @param parameters: Dictionary - Effect parameters to check
## @return: bool - True if effect has ValidTargets parameter (requires targeting)
static func requires_target(parameters: Dictionary) -> bool:
	"""Check if effect parameters indicate targeting is required"""
	# Effect requires targeting if it has ValidTargets parameter
	return parameters.has("ValidTargets")

## Check whether this effect can validly resolve given the current game state.
## Return false to signal that the primary effect has no valid targets/conditions,
## which causes AbilityManager to run the alternativeResolve fallback (if one is set).
## Override in subclasses for effects that have optional targets or conditions.
## @return: bool - True (default) means "go ahead and execute"
func can_execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> bool:
	# Check mandatory Condition$ if specified
	var condition: String = parameters.get("Condition", "")
	if not condition.is_empty() and not game_context.check_effect_condition(condition, source_card_data):
		return false

	# If the effect specified ValidTargets, require that targets were actually resolved
	if parameters.has("ValidTargets") and parameters.get("Targets", []).is_empty():
		return false

	return true

## Return all in-play cards matching ValidCard$, selected per Choice$/NumCard$.
## Choice$ Random (default) picks without UI; Choice$ Player triggers selection UI.
func get_affected_cards(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var all_in_play: Array[CardData] = game_context.game_data.get_cards_in_play()
	return await filter_and_select_cards(all_in_play, parameters, "play", "Select Target", source_card_data, game_context)

## Sync check: true if any in-play card matches the ValidCard$ filter.
## Use this in can_execute overrides to avoid the async cost of get_affected_cards.
func _has_valid_affected_cards(parameters: Dictionary, game_context: Game) -> bool:
	var valid_card: String = parameters.get("ValidCard", "")
	if valid_card.is_empty():
		return true
	var criteria = GameUtility.parseCriteria(valid_card)
	for card in game_context.game_data.get_cards_in_play():
		if GameUtility.matchesCardDataCriteria(card, criteria):
			return true
	return false

## Select cards from a filtered list based on choice type
## @param filtered_cards: Array[CardData] - Cards available for selection
## @param num_to_select: int - Number of cards to select
## @param choice_type: String - Selection method: "Random", "Player", or default (first N)
## @param valid_card_type: String - Type description for UI (e.g., "Creature")
## @param selection_context: String - Context for UI (e.g., "Move Card")
## @param source_card_data: CardData - The card that is the source of this effect
## @param game_context: Game - The game context for accessing game state
## @return: Array[CardData] - Selected cards
func select_cards_from_list(filtered_cards: Array[CardData], num_to_select: int, choice_type: String, valid_card_type: String, selection_context: String, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var selected_cards: Array[CardData] = []
	
	if choice_type == "Random":
		# Shuffle and take first N cards
		filtered_cards.shuffle()
		for i in range(num_to_select):
			selected_cards.append(filtered_cards[i])
	elif choice_type == "Player":
		# Player selection - trigger selection UI
		var requirement = {
			"count": num_to_select,
			"type": valid_card_type
		}
		selected_cards = await game_context.start_card_selection(requirement, filtered_cards, selection_context, source_card_data)
	else:
		# Default: take first N cards
		for i in range(num_to_select):
			selected_cards.append(filtered_cards[i])
	
	return selected_cards

## Filter and select cards from a list based on effect parameters
## Handles ValidCard filtering and Choice selection.
## @param cards_to_filter: Array[CardData] - Source cards to filter
## @param parameters: Dictionary - Effect parameters (ValidCard, Choice, NumCard, etc.)
## @param origin_zone_str: String - Zone name for error messages
## @param selection_context: String - Context for UI (e.g., "Move Card")
## @param source_card_data: CardData - The card that is the source of this effect
## @param game_context: Game - The game context for accessing game state
## @return: Array[CardData] - Filtered and selected cards (empty if none found or cancelled)
func filter_and_select_cards(cards_to_filter: Array[CardData], parameters: Dictionary, origin_zone_str: String, selection_context: String, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var valid_card: String = parameters.get("ValidCard", "Card")
	var choice_type: String = parameters.get("Choice", "Random")
	var num_cards: int = parameters.get("NumCard", 1)
	
	# Filter cards by ValidCard criteria using GameUtility's filtering
	var criteria = GameUtility.parseCriteria(valid_card)
	var filtered_cards: Array[CardData] = []
	for card_data in cards_to_filter:
		if GameUtility.matchesCardDataCriteria(card_data, criteria):
			filtered_cards.append(card_data)
	
	if filtered_cards.is_empty():
		print("⚠️ No valid cards found in ", origin_zone_str, " matching ", valid_card)
		return []
	
	# Limit number of cards to available cards
	var cards_to_select = min(num_cards, filtered_cards.size())
	
	# Select cards using the selection method
	var selected_cards = await select_cards_from_list(
		filtered_cards,
		cards_to_select,
		choice_type,
		valid_card,
		selection_context,
		source_card_data,
		game_context
	)
	
	return selected_cards
