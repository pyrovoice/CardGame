extends Effect
class_name DealDamageEffect

## Effect that deals damage to a target

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var damage_amount = parameters.get("NumDamage", 1)
	var valid_targets = parameters.get("ValidTargets", "Any")
	
	# Check if targets are pre-specified (from game.gd spell casting)
	var preselected_targets = parameters.get("Targets", [])
	
	if preselected_targets.size() > 0:
		# Use pre-selected targets (now CardData)
		var target_data: CardData = preselected_targets[0]
		var target_node = target_data.get_card_object()
		if not target_node or not is_instance_valid(target_node):
			print("⚠️ Target no longer exists")
			return
			
		print("⚡ ", source_card_data.cardName, " deals ", damage_amount, " damage to ", target_data.cardName)
		
		# Apply damage
		target_node.receiveDamage(damage_amount)
		
		# Show damage animation
		AnimationsManagerAL.show_floating_text(game_context, target_node.global_position, "-" + str(damage_amount), Color.RED)
		
		# Resolve state-based actions after damage
		game_context.resolveStateBasedAction()
		return
	
	print("⚡ ", source_card_data.cardName, " needs to deal ", damage_amount, " damage to target (", valid_targets, ")")
	
	# Query GameData for cards in play
	var cards_data = game_context.game_data.get_cards_in_play()
	
	# Filter CardData based on valid targets
	var possible_targets_data: Array[CardData] = []
	match valid_targets:
		"Any":
			possible_targets_data = cards_data
		"Creature":
			for card_data in cards_data:
				if card_data.hasType(CardData.CardType.CREATURE):
					possible_targets_data.append(card_data)
		_:
			print("❌ Unknown target type: ", valid_targets)
			return
	
	if possible_targets_data.is_empty():
		print("⚠️ No valid targets for ", source_card_data.cardName)
		return
	
	# Get the Card object from CardData (if it still exists) for animation purposes
	var casting_card = source_card_data.get_card_object()
	if not casting_card:
		print("⚠️ Cannot select target - source card no longer exists (card was destroyed)")
		return
	
	# Start target selection with CardData
	var requirement = {
		"valid_card": "Any",  # We've already filtered the possible_targets_data
		"count": 1
	}
	
	print("🎯 Starting target selection for ", source_card_data.cardName)
	var selected_targets = await game_context.start_card_selection(requirement, possible_targets_data, "spell_target_" + source_card_data.cardName, casting_card)
	
	if selected_targets.is_empty():
		print("❌ No target selected for ", source_card_data.cardName)
		return
	
	var target_data: CardData = selected_targets[0]
	var target_node = target_data.get_card_object()
	if not target_node or not is_instance_valid(target_node):
		print("⚠️ Target no longer exists")
		return
		
	print("⚡ ", source_card_data.cardName, " deals ", damage_amount, " damage to ", target_data.cardName)
	
	# Apply damage
	target_node.receiveDamage(damage_amount)
	
	# Show damage animation
	AnimationsManagerAL.show_floating_text(game_context, target_node.global_position, "-" + str(damage_amount), Color.RED)
	
	# Resolve state-based actions after damage
	game_context.resolveStateBasedAction()

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("NumDamage")

func get_description(parameters: Dictionary) -> String:
	var damage = parameters.get("NumDamage", 1)
	var targets = parameters.get("ValidTargets", "Any")
	return "Deal " + str(damage) + " damage to " + targets
