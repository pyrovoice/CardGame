extends Effect
class_name HealGameEffect

## Heals damage off a creature. Amount defaults to 1 and can be adjusted by replacement effects
## (see ReplacementEffectRegistry.apply_replacement_effects, called with EffectType.Type.HEAL).

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var preselected_targets: Array = targets
	if preselected_targets.is_empty():
		preselected_targets.assign(Effect.resolve_affected(parameters))
	if preselected_targets.is_empty():
		print("⚠️ HealGameEffect missing pre-resolved Targets")
		return []

	var target_data: CardData = preselected_targets[0]
	if not target_data:
		print("⚠️ Target no longer exists")
		return []

	print("💤 ", target_data.cardName, " rests and heals ", amount, " damage")
	target_data.heal(amount)

	var target_node := target_data.get_card_object()
	if target_node and is_instance_valid(target_node):
		AnimationsManagerAL.show_floating_text(game_context, target_node.global_position, "+" + str(amount), Color.GREEN)

	return [target_data]

func get_description(parameters: Dictionary) -> String:
	var heal_amount = parameters.get("Amount", 1)
	return "Heal " + str(heal_amount) + " damage"
