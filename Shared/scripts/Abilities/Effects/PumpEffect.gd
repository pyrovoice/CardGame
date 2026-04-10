extends Effect
class_name PumpEffect

## Effect that increases/decreases a creature's power temporarily

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var power_bonus = parameters.get("PowerBonus", 0)
	var valid_targets = parameters.get("ValidTargets", "Creature")
	var duration = parameters.get("Duration", "EndOfTurn")
	
	# Effects expect targets to be resolved by the caller.
	var preselected_targets: Array = parameters.get("Targets", [])
	if preselected_targets.is_empty():
		print("⚠️ PumpEffect missing pre-resolved Targets (ValidTargets=", valid_targets, ")")
		return

	var target_data: CardData = preselected_targets[0]
	var target_node = target_data.get_card_object()
	if not target_data:
		print("⚠️ Target no longer exists")
		return
		
	print("✨ ", source_card_data.cardName, " pumps ", target_data.cardName, " by +", power_bonus, " power")
	
	# Apply the power boost
	_apply_power_boost(target_data, power_bonus, duration)
	
	# Show buff animation
	if target_node and is_instance_valid(target_node):
		AnimationsManagerAL.show_floating_text(game_context, target_node.global_position, "+" + str(power_bonus) + " Power", Color.GREEN)

func _apply_power_boost(target_card_data: CardData, power_bonus: int, duration: String):
	"""Apply a temporary power boost to a card"""
	if power_bonus >= 0:
		CardModifier.modify_card(target_card_data, "power_boost", {"amount": power_bonus}, duration)
	else:
		# Handle negative values as power reduction
		CardModifier.modify_card(target_card_data, "power_reduction", {"amount": -power_bonus}, duration)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("PowerBonus")

func get_description(parameters: Dictionary) -> String:
	var bonus = parameters.get("PowerBonus", 0)
	var targets = parameters.get("ValidTargets", "Creature")
	var sign = "+" if bonus >= 0 else ""
	return "Give " + targets + " " + sign + str(bonus) + " power"
