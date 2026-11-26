extends Effect
class_name WeakenEffect

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var candidates: Array[CardData] = targets
	if candidates.is_empty():
		candidates = Effect.resolve_affected(parameters, source_card_data, game_context)

	var target_condition: String = parameters.get("TargetCondition", "")
	var affected_cards: Array[CardData] = []
	for target_card: CardData in candidates:
		if not target_condition.is_empty() and not AbilityManagerAL.evaluateCondition(target_condition, source_card_data, game_context, target_card):
			continue
		var reduction: int = power_bonus if parameters.has("PowerBonus") else target_card.power
		if reduction <= 0:
			continue
		CardModifier.modify_card(target_card, "power_reduction", {"amount": reduction}, duration, game_context)
		affected_cards.append(target_card)
	return affected_cards

func get_description(parameters: Dictionary) -> String:
	var bonus = parameters.get("PowerBonus", "its own power")
	return "Weaken " + str(parameters.get("Affected", parameters.get("ValidTargets", "target"))) + " by " + str(bonus)
