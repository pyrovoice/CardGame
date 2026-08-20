extends RefCounted
class_name Effect

## Base class for all ability effects
## Each effect type should extend this and implement execute()

## Execute the effect and return the cards it acted on.
## Return an empty array to signal the effect was suppressed (player skipped, condition not met,
## not enough resources, etc.) — the sub-ability chain will NOT fire in that case.
## Return a non-empty array for success; those cards become the new remembered set.
## For effects that don't act on specific cards (e.g. AddGold, Draw), return [source_card_data]
## as a "ran successfully" sentinel so the sub-ability still fires.
func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	push_error("Effect.execute() must be implemented by subclass")
	return []

## Runner — called by EffectFactory instead of execute() directly.
## Handles the full lifecycle: declare selections → execute → remember → sub-ability.
func run(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> void:
	# Fulfil any declared selections before execute() so effects need not call game_context for UI
	var requests: Array = declare_selections(parameters, source_card_data, game_context)
	for request: SelectionRequest in requests:
		SelectionRequest.current = request
		request.with_casting_card(source_card_data).with_context("selection_for_" + get_class())
		var selected = await game_context.start_card_selection()
		parameters[request.result_key] = selected  # null = cancelled, [] = confirmed-empty

	Effect.remembered_cards = await execute(parameters, source_card_data, game_context)
	await _run_sub_ability(parameters, source_card_data, game_context)

## Validate that required parameters are present
## @param parameters: Dictionary - Effect parameters to validate
## @return: bool - True if parameters are valid
func validate_parameters(parameters: Dictionary) -> bool:
	# Base implementation - override in subclasses for specific validation
	return true

## Declare player-selections this effect needs resolved before execute() is called.
## Override when the effect needs a player choice upfront.
## run() fulfils each SelectionRequest via game_context.start_card_selection() and
## injects the result into parameters[request.result_key] before calling execute().
## Default: no selections needed (effects may still call game_context directly inside
## execute(), but that is discouraged — declare_selections is the preferred path).
func declare_selections(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array:
	return []

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

# ─── Sub-Ability + Remembered Cards ──────────────────────────────────────────

## Cards affected by the last resolved effect.
## Overwritten automatically by each effect after it acts on its targets.
## Sub-abilities reference this set via Affected$ Card.Remembered.
static var remembered_cards: Array[CardData] = []

## Overwrite the remembered set with the given cards.
static func remember(cards: Array[CardData]) -> void:
	remembered_cards = cards

## If parameters include Affected$ Card.Remembered, return the remembered cards.
## Otherwise returns an empty array — caller should fall through to its own targeting.
static func resolve_affected(parameters: Dictionary) -> Array[CardData]:
	if parameters.get("Affected", "") == "Card.Remembered":
		return remembered_cards
	return []

## Execute the sub-ability chain embedded in parameters, if one was defined (SubAbility$).
## CardLoader pre-resolves the SVar name into subAbility_effect_type + subAbility_parameters
## at load time. Call this at the end of execute() — or inside a success branch for
## conditional sub-abilities (e.g. only when a cost is paid).
func _run_sub_ability(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> void:
	var sub_type_str: String = parameters.get("subAbility_effect_type", "")
	if sub_type_str.is_empty():
		return
	var sub_type = EffectType.string_to_type(sub_type_str)
	var sub_params: Dictionary = parameters.get("subAbility_parameters", {})
	await EffectFactory.execute_effect(sub_type, sub_params, source_card_data, game_context)

## Resolve a parameter value that may be a literal int or a runtime formula string.
## Formulas are evaluated against Effect.remembered_cards at execution time.
##
## Supported formulas:
##   "Card.Remembered.Power"  → power of the first remembered card (0 if none)
##
## Example card text:  NumDmg$ Card.Remembered.Power
static func resolve_numeric(value) -> int:
	if value is int:
		return value
	if value is String:
		match value:
			"Card.Remembered.Power":
				if not remembered_cards.is_empty():
					return remembered_cards[0].power
				return 0
		# Fall back to plain integer parse
		if value.is_valid_int():
			return int(value)
		push_warning("Effect.resolve_numeric: unknown formula '" + str(value) + "', defaulting to 0")
		return 0
	return 0

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
		# Player selection - configure global request then trigger
		SelectionRequest.reset()\
				.with_pool(filtered_cards)\
				.with_count(num_to_select)\
				.with_description(valid_card_type)\
				.with_context(selection_context)\
				.with_casting_card(source_card_data)
		var result = await game_context.start_card_selection()
		# null = cancelled; treat as empty (no cards selected)
		selected_cards.assign(result if result != null else [])
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
