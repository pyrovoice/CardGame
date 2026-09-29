extends Effect
class_name WeakenEffect

## Reduce a creature's power - the debuff opposite of Pump.
## Affected$/ValidTargets$ selects candidates. TargetCondition$ (optional) is evaluated per
## candidate via AbilityManager.evaluateCondition(condition, source_card_data, game_context, candidate) -
## "Self" refers to source_card_data, "Target" refers to the candidate being checked.
## If PowerBonus$ is omitted, each qualifying candidate loses exactly its own current power
## (a fixed amount computed once, not a dynamic "set power to 0").

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var candidates: Array = targets
	if candidates.is_empty():
		candidates.assign(Effect.resolve_affected(parameters, source_card_data, game_context))

	var target_condition: String = parameters.get("TargetCondition", "")
	var affected: Array[CardData] = []
	for target in candidates:
		if not target_condition.is_empty() and not AbilityManagerAL.evaluateCondition(target_condition, source_card_data, game_context, target):
			continue

		var reduction: int = power_bonus if parameters.has("PowerBonus") else target.power
		if reduction <= 0:
			continue

		print("🪨 ", source_card_data.cardName, " weakens ", target.cardName, " by ", reduction, " power")
		CardModifier.modify_card(target, "power_reduction", {"amount": reduction}, duration, game_context)
		affected.append(target)

	return affected

func get_description(parameters: Dictionary) -> String:
	var bonus = parameters.get("PowerBonus", "its own power")
	return "Weaken " + str(parameters.get("Affected", parameters.get("ValidTargets", "target"))) + " by " + str(bonus)
