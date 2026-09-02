extends Effect
class_name RecycleEffect

## Exile Num cards at random from the controller's graveyard.
## Optionally prompts the player when Mandatory is false ("You may Recycle N").
## Remembers the exiled cards so sub-abilities can reference them via Affected$ Card.Remembered.
## Sub-ability (SubAbility$) fires only on success — use it for the "If you do" effect.
##
## Parameters:
##   Num (int, default 1)               — cards to exile from graveyard
##   Mandatory (bool, default true)     — false = player can decline
##   subAbility_effect_type (String)    — follow-up effect type (embedded by CardLoader)
##   subAbility_parameters (Dictionary) — follow-up effect parameters

func can_execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> bool:
	# Base class handles pre-selected targets, conditions, parsing, and ValidTargets checks
	if not super.can_execute(parameters, source_card_data, game_context):
		return false
	
	print("🔍 [RECYCLE CAN_EXECUTE] mandatory=", mandatory, ", num_cards=", num_cards)
	
	# Use parsed instance variables
	if not mandatory:
		print("🔍 [RECYCLE CAN_EXECUTE] Optional recycle, returning true")
		return true  # Optional recycle can always start — player decides at runtime
	var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if source_card_data.playerControlled else GameZone.e.GRAVEYARD_OPPONENT
	var graveyard_size = game_context.game_data.get_cards_in_zone(graveyard_zone).size()
	var result = graveyard_size >= num_cards
	print("🔍 [RECYCLE CAN_EXECUTE] Mandatory recycle: graveyard_size=", graveyard_size, ", num_cards=", num_cards, ", result=", result)
	return result

func declare_selections(parameters: Dictionary, _source_card_data: CardData, _game_context: Game) -> Array:
	# mandatory and num_cards are already parsed by _parse_parameters()
	if mandatory:
		return []  # can_execute() already guards the precondition; no player choice needed
	# Binary "You may" prompt — empty pool, custom confirm label, Cancel = skip.
	return [
		SelectionRequest.new()
			.optional()
			.with_confirm_text("Recycle " + str(num_cards))
			.with_result_key("RecycleChoice")
	]

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# mandatory and num_cards are already parsed by _parse_parameters()
	var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if source_card_data.playerControlled else GameZone.e.GRAVEYARD_OPPONENT

	var graveyard_cards = game_context.game_data.get_cards_in_zone(graveyard_zone)

	if graveyard_cards.size() < num_cards:
		print("⚠️ [RECYCLE] Not enough cards in graveyard (need ", num_cards, ", have ", graveyard_cards.size(), ")")
		return []

	if not mandatory:
		# run() injected the player's answer: null = Cancel/skip, [] = Confirm/proceed
		if parameters.get("RecycleChoice") == null:
			print("♻️ [RECYCLE] Player skipped Recycle ", num_cards)
			return []  # Empty return — sub-ability will not fire

	# Re-fetch after prompt in case graveyard changed
	graveyard_cards = game_context.game_data.get_cards_in_zone(graveyard_zone)
	if graveyard_cards.size() < num_cards:
		print("⚠️ [RECYCLE] Graveyard no longer has enough cards after prompt")
		return []

	var cards_copy: Array[CardData] = graveyard_cards.duplicate()
	cards_copy.shuffle()
	var to_exile = cards_copy.slice(0, num_cards)

	for card in to_exile:
		print("♻️ [RECYCLE] Exiling ", card.cardName, " from graveyard")
		await game_context.execute_move_card(card, GameZone.e.RECYCLE_ZONE, graveyard_zone)

	print("♻️ [RECYCLE] Successfully recycled ", to_exile.size(), " card(s)")
	return to_exile  # Non-empty — sub-ability fires

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(parameters: Dictionary) -> String:
	var num = parameters.get("Num", 1)
	var mandatory = parameters.get("Mandatory", true)
	if mandatory:
		return "Recycle " + str(num)
	return "You may Recycle " + str(num)
