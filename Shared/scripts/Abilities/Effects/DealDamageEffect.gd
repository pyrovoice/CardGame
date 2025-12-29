extends Effect
class_name DealDamageEffect

## Effect that deals damage to a target

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var damage_amount = parameters.get("NumDamage", 1)
	var valid_targets = parameters.get("ValidTargets", "Any")
	
	# Check if targets are pre-specified (from game.gd spell casting)
	var preselected_targets = parameters.get("Targets", [])
	
	if preselected_targets.size() > 0:
		# Use pre-selected targets
		var target = preselected_targets[0]
		print("⚡ ", source_card_data.cardName, " deals ", damage_amount, " damage to ", target.cardData.cardName)
		
		# Apply damage
		target.receiveDamage(damage_amount)
		
		# Show damage animation
		AnimationsManagerAL.show_floating_text(game_context, target.global_position, "-" + str(damage_amount), Color.RED)
		
		# Resolve state-based actions after damage
		game_context.resolveStateBasedAction()
		return
	
	print("⚡ ", source_card_data.cardName, " needs to deal ", damage_amount, " damage to target (", valid_targets, ")")
	
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
	print("⚡ ", source_card_data.cardName, " deals ", damage_amount, " damage to ", target.cardData.cardName)
	
	# Apply damage
	target.receiveDamage(damage_amount)
	
	# Show damage animation
	AnimationsManagerAL.show_floating_text(game_context, target.global_position, "-" + str(damage_amount), Color.RED)
	
	# Resolve state-based actions after damage
	game_context.resolveStateBasedAction()

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("NumDamage")

func get_description(parameters: Dictionary) -> String:
	var damage = parameters.get("NumDamage", 1)
	var targets = parameters.get("ValidTargets", "Any")
	return "Deal " + str(damage) + " damage to " + targets
