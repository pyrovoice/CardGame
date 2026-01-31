extends Effect
class_name SwitchPositionsEffect

## Effect that switches positions between two cards in combat
## Used by the Elusive keyword

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var switch_with = parameters.get("SwitchWith", "")
	var only_same_location = parameters.get("OnlySameLocation", true)
	
	print("🔄 [SWITCH] ", source_card_data.cardName, " switching positions with: ", switch_with)
	
	# Get the source card (Elusive card)
	var source_card = source_card_data.get_card_object()
	if not source_card or not is_instance_valid(source_card):
		print("⚠️ Source card doesn't exist or is invalid")
		return
	
	var source_parent = source_card.get_parent()
	if not source_parent is CombatantFightingSpot:
		print("⚠️ Source card is not in a combat spot")
		return
	
	var source_spot = source_parent as CombatantFightingSpot
	
	# Determine the target card to switch with
	var target_card: Card = null
	var target_spot: CombatantFightingSpot = null
	
	if switch_with == "TriggeredCard":
		# The triggered card should be passed in parameters (from trigger context)
		var triggered_card_data = parameters.get("TriggeredCardData", null)
		if not triggered_card_data:
			print("⚠️ No TriggeredCardData in parameters")
			return
		
		target_card = triggered_card_data.get_card_object()
		if not target_card or not is_instance_valid(target_card):
			print("⚠️ Triggered card doesn't exist or is invalid")
			return
		
		var target_parent = target_card.get_parent()
		if not target_parent is CombatantFightingSpot:
			print("⚠️ Triggered card is not in a combat spot")
			return
		
		target_spot = target_parent as CombatantFightingSpot
	else:
		print("⚠️ Unknown SwitchWith value: ", switch_with)
		return
	
	# Check if both cards are in the same combat location (if required)
	if only_same_location:
		var source_location = source_spot.get_parent()
		var target_location = target_spot.get_parent()
		
		if source_location != target_location:
			print("⚠️ Cards are not in the same combat location")
			return
	
	# Perform the switch using game's exchange function
	print("🔄 Switching ", source_card_data.cardName, " with ", target_card.cardData.cardName)
	game_context.exchange_card_in_spots(source_spot, target_spot)
	
	# Show visual feedback
	AnimationsManagerAL.show_floating_text(
		game_context, 
		source_card.global_position, 
		"Elusive!", 
		Color.CYAN
	)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("SwitchWith")

func get_description(parameters: Dictionary) -> String:
	var switch_with = parameters.get("SwitchWith", "unknown")
	return "Switch positions with " + switch_with
