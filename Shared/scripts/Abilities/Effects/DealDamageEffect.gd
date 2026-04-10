extends Effect
class_name DealDamageEffect

## Effect that deals damage to a target

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var damage_amount = parameters.get("NumDamage", 1)
	var valid_targets = parameters.get("ValidTargets", "Any")
	# Effects expect targets to be resolved by the caller.
	var preselected_targets: Array = parameters.get("Targets", [])
	if preselected_targets.is_empty():
		print("⚠️ DealDamageEffect missing pre-resolved Targets (ValidTargets=", valid_targets, ")")
		return

	var target_data: CardData = preselected_targets[0]
	var target_node: Card
	if not target_data:
		print("⚠️ Target no longer exists")
		return
	
	print("⚡ ", source_card_data.cardName, " deals ", damage_amount, " damage to ", target_data.cardName)
	
	# Apply damage via CardData
	target_data.receiveDamage(damage_amount)
	
	# Show damage animation only if Card node exists
	target_node = target_data.get_card_object()
	if target_node and is_instance_valid(target_node):
		AnimationsManagerAL.show_floating_text(game_context, target_node.global_position, "-" + str(damage_amount), Color.RED)
	
	# Resolve state-based actions after damage
	game_context.resolveStateBasedAction()

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("NumDamage")

func get_description(parameters: Dictionary) -> String:
	var damage = parameters.get("NumDamage", 1)
	var targets = parameters.get("ValidTargets", "Any")
	return "Deal " + str(damage) + " damage to " + targets
