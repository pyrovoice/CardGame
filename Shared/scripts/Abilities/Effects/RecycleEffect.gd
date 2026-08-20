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
	var mandatory: bool = parameters.get("Mandatory", true)
	if not mandatory:
		return true  # Optional recycle can always start — player decides at runtime
	var num: int = int(parameters.get("Num", 1))
	var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if source_card_data.playerControlled else GameZone.e.GRAVEYARD_OPPONENT
	return game_context.game_data.get_cards_in_zone(graveyard_zone).size() >= num

func declare_selections(parameters: Dictionary, _source_card_data: CardData, _game_context: Game) -> Array:
	var mandatory: bool = parameters.get("Mandatory", true)
	if mandatory:
		return []  # can_execute() already guards the precondition; no player choice needed
	var num: int = int(parameters.get("Num", 1))
	# Binary "You may" prompt — empty pool, custom confirm label, Cancel = skip.
	return [
		SelectionRequest.new()
			.optional()
			.with_confirm_text("Recycle " + str(num))
			.with_result_key("RecycleChoice")
	]

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var num: int = int(parameters.get("Num", 1))
	var mandatory: bool = parameters.get("Mandatory", true)
	var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if source_card_data.playerControlled else GameZone.e.GRAVEYARD_OPPONENT

	var graveyard_cards = game_context.game_data.get_cards_in_zone(graveyard_zone)

	if graveyard_cards.size() < num:
		print("⚠️ [RECYCLE] Not enough cards in graveyard (need ", num, ", have ", graveyard_cards.size(), ")")
		return []

	if not mandatory:
		# run() injected the player's answer: null = Cancel/skip, [] = Confirm/proceed
		if parameters.get("RecycleChoice") == null:
			print("♻️ [RECYCLE] Player skipped Recycle ", num)
			return []  # Empty return — sub-ability will not fire

	# Re-fetch after prompt in case graveyard changed
	graveyard_cards = game_context.game_data.get_cards_in_zone(graveyard_zone)
	if graveyard_cards.size() < num:
		print("⚠️ [RECYCLE] Graveyard no longer has enough cards after prompt")
		return []

	var cards_copy: Array[CardData] = graveyard_cards.duplicate()
	cards_copy.shuffle()
	var to_exile = cards_copy.slice(0, num)

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
