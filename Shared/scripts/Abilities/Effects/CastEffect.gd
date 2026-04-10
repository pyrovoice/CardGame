extends Effect
class_name CastEffect

## Effect that plays/casts a card from any zone (deck, hand, graveyard, etc.)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var target = parameters.get("Target", "")
	
	if target == "Self":
		# Cast the source card itself (e.g., Eyepatch the Pirate from deck)
		print("🎭 [CAST] Casting ", source_card_data.cardName, " from its current zone")

		# Use game-effect execution path (not player-input play path),
		# so casting from deck/graveyard bypasses hand-only source checks.
		var empty_selections = SelectionManager.CardPlaySelections.new()
		await game_context.tryPayAndSelectsForCardPlay(source_card_data, empty_selections, false)
	else:
		print("❌ Unsupported Cast target: ", target)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Target")

func get_description(parameters: Dictionary) -> String:
	var target = parameters.get("Target", "Self")
	return "Cast " + target + " from its current zone"
