extends Effect
class_name CastEffect

## Effect that plays/casts a card from any zone (deck, hand, graveyard, etc.)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var target = parameters.get("Target", "")
	
	if target == "Self":
		print("🎭 [CAST] Casting ", source_card_data.cardName, " from its current zone")
		var empty_selections = SelectionManager.CardPlaySelections.new()
		await game_context.tryPayAndSelectsForCardPlay(source_card_data, empty_selections, false)
		return [source_card_data]
	else:
		print("❌ Unsupported Cast target: ", target)
		return []

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Target")

func get_description(parameters: Dictionary) -> String:
	var target = parameters.get("Target", "Self")
	return "Cast " + target + " from its current zone"
