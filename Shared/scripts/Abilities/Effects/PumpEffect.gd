extends Effect
class_name PumpEffect

## Effect that increases/decreases a creature's power temporarily

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var power_bonus = parameters.get("PowerBonus", 0)
	var valid_targets = parameters.get("ValidTargets", "Creature")
	var duration = parameters.get("Duration", "EndOfTurn")
	
	# Check if targets are pre-specified (from game.gd spell casting)
	var preselected_targets = parameters.get("Targets", [])
	
	if preselected_targets.size() > 0:
		# Use pre-selected targets
		var target = preselected_targets[0]
		print("✨ ", source_card_data.cardName, " pumps ", target.cardData.cardName, " by +", power_bonus, " power")
		
		# Apply the power boost
		_apply_power_boost(target, power_bonus, duration)
		
		# Show buff animation
		AnimationsManagerAL.show_floating_text(game_context, target.global_position, "+" + str(power_bonus) + " Power", Color.GREEN)
		return
	
	print("✨ ", source_card_data.cardName, " needs to pump a creature +", power_bonus, " power (", valid_targets, ")")
	
	# Get all possible targets using centralized filtering
	var possible_targets: Array[Card] = GameUtility.filterCardsByParameters(
		game_context.getAllCardsInPlay(),
		valid_targets,
		game_context
	)
	
	if possible_targets.is_empty():
		print("⚠️ No valid targets for ", source_card_data.cardName)
		return
	
	# Get the Card object from CardData (if it still exists)
	var casting_card = source_card_data.get_card_object()
	if not casting_card:
		print("⚠️ Cannot select target - source card no longer exists (card was destroyed)")
		return
	
	# Start target selection
	var requirement = {
		"valid_card": "Any",  # We've already filtered the possible_targets
		"count": 1
	}
	
	print("🎯 Starting target selection for ", source_card_data.cardName)
	var selected_targets = await game_context.start_card_selection(requirement, possible_targets, "spell_target_" + source_card_data.cardName, casting_card)
	
	if selected_targets.is_empty():
		print("❌ No target selected for ", source_card_data.cardName)
		return
	
	var target = selected_targets[0]
	print("✨ ", source_card_data.cardName, " pumps ", target.cardData.cardName, " by +", power_bonus, " power")
	
	# Apply the power boost
	_apply_power_boost(target, power_bonus, duration)
	
	# Show buff animation
	AnimationsManagerAL.show_floating_text(game_context, target.global_position, "+" + str(power_bonus) + " Power", Color.GREEN)

func _apply_power_boost(target_card: Card, power_bonus: int, duration: String):
	"""Apply a temporary power boost to a card"""
	if power_bonus >= 0:
		CardModifier.modify_card(target_card, "power_boost", {"amount": power_bonus}, duration)
	else:
		# Handle negative values as power reduction
		CardModifier.modify_card(target_card, "power_reduction", {"amount": -power_bonus}, duration)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("PowerBonus")

func get_description(parameters: Dictionary) -> String:
	var bonus = parameters.get("PowerBonus", 0)
	var targets = parameters.get("ValidTargets", "Creature")
	var sign = "+" if bonus >= 0 else ""
	return "Give " + targets + " " + sign + str(bonus) + " power"
