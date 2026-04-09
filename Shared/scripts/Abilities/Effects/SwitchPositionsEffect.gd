extends Effect
class_name SwitchPositionsEffect

## Effect that switches positions between two cards in combat
## Used by the Elusive keyword

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var switch_with = parameters.get("SwitchWith", "")
	var only_same_location = parameters.get("OnlySameLocation", true)
	
	print("🔄 [SWITCH] ", source_card_data.cardName, " switching positions with: ", switch_with)
	
	# Verify source card is in a combat zone
	var source_zone = game_context.game_data.get_card_zone(source_card_data)
	if not GameZone.is_combat_zone(source_zone):
		print("⚠️ Source card is not in a combat zone")
		return
	
	# Determine the target card to switch with
	var target_card_data: CardData = null
	
	if switch_with == "TriggeredCard":
		# The triggered card should be passed in parameters (from trigger context)
		target_card_data = parameters.get("TriggeredCardData", null)
		if not target_card_data:
			print("⚠️ No TriggeredCardData in parameters")
			return
	elif switch_with == "LastOther":
		# Find the last card in the same combat zone that isn't the source card
		var cards_in_zone = game_context.game_data.get_cards_in_zone(source_zone)
		
		if cards_in_zone.size() <= 1:
			print("⚠️ No other cards in combat zone to switch with")
			return
		
		# Get the last card that isn't the source
		for i in range(cards_in_zone.size() - 1, -1, -1):
			if cards_in_zone[i] != source_card_data:
				target_card_data = cards_in_zone[i]
				break
		
		if not target_card_data:
			print("⚠️ Could not find another card to switch with")
			return
	else:
		print("⚠️ Unknown SwitchWith value: ", switch_with)
		return
	
	# Verify target card is in a combat zone
	var target_zone = game_context.game_data.get_card_zone(target_card_data)
	if not GameZone.is_combat_zone(target_zone):
		print("⚠️ Triggered card is not in a combat zone")
		return
	
	# Check if both cards are in the same combat location (if required)
	if only_same_location:
		if source_zone != target_zone:
			print("⚠️ Cards are not in the same combat location")
			return
	
	# Perform the switch using game's new exchange function
	print("🔄 Switching ", source_card_data.cardName, " with ", target_card_data.cardName)
	var success = game_context.exchange_card_positions_in_combat(source_card_data, target_card_data)
	
	if success:
		# Show visual feedback
		var source_card = source_card_data.get_card_object()
		if source_card and is_instance_valid(source_card):
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
