extends Effect
class_name DraftEffect

## Effect that lets the player draft a card from an archetype pool to hand.
## Parameters:
##   Archetype$           — pool to draft from (e.g. "Punglynd")
##   Mandatory$           — false = show Skip button (default: true)
##   AlternativeResolve$  — SVar to run when pool is empty (can_execute=false)
##                          Also executed inline when the player skips (Mandatory$ false)

func can_execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> bool:
	return not _get_draft_pool(parameters).is_empty()

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var pool = _get_draft_pool(parameters)

	# Pick up to 3 unique cards at random for the draft window
	pool.shuffle()
	var choices: Array[CardData] = []
	choices.assign(pool.slice(0, min(3, pool.size())))

	var mandatory: bool = parameters.get("Mandatory", true)
	var picker: CardChoicePicker = game_context.game_view.card_choice_picker

	if not mandatory:
		game_context.game_view.push_action_buttons(
			{"text": "Skip", "callback": func(): picker.skip()},
			null,  # hide secondary during draft
			picker  # auto-pops when picker hides
		)

	picker.show_choices(choices, not mandatory)

	var chosen_index: int = await picker.choice_made

	if chosen_index == -1:
		# Player skipped — execute inline fallback if one is defined
		var fallback_type_str: String = parameters.get("alternativeResolve_effect_type", "")
		if not fallback_type_str.is_empty():
			var fallback_type = EffectType.string_to_type(fallback_type_str)
			var fallback_params: Dictionary = parameters.get("alternativeResolve_parameters", {})
			await EffectFactory.execute_effect(fallback_type, fallback_params, source_card_data, game_context)
		return

	# Create the chosen card template as a real card in the player's hand
	game_context.createCardData(choices[chosen_index], GameZone.e.HAND_PLAYER, source_card_data.playerOwned)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Archetype")

func get_description(parameters: Dictionary) -> String:
	return "Draft a " + parameters.get("Archetype", "card") + " to hand"

# Returns the filtered pool: archetype cards, no legendaries
func _get_draft_pool(parameters: Dictionary) -> Array[CardData]:
	var archetype_str: String = parameters.get("Archetype", "")
	var archetype_key = archetype_str.to_upper()

	var archetype: int = CardLoader.Archetype.UNKNOWN
	if archetype_key in CardLoader.Archetype:
		archetype = CardLoader.Archetype[archetype_key]

	if archetype == CardLoader.Archetype.UNKNOWN:
		push_error("DraftEffect: unknown Archetype$ '" + archetype_str + "'")
		return []

	var pool: Array[CardData] = []
	for card in CardLoaderAL.get_archetype_pool(archetype):
		if not card.hasType(CardData.CardType.LEGENDARY):
			pool.append(card)
	return pool
