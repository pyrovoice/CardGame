extends Effect
class_name AddTypeEffect

## Effect that adds types/subtypes to cards
## Expects targets to be pre-resolved and passed in parameters["Targets"]

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	# Effects do not resolve/select targets; caller must provide them.
	var target_cards: Array[CardData] = parameters.get("Targets", [])

	if target_cards.is_empty():
		print("⚠️ AddTypeEffect missing pre-resolved Targets")
		return
	
	# Parse types to add
	var types_to_add = parameters.get("Types", "")
	if types_to_add.is_empty():
		print("❌ No types specified for AddType effect")
		return
	
	# Parse duration
	var duration = parameters.get("Duration", "Permanent")
	
	# Add the types to each target card
	for target_card_data in target_cards:
		_add_types_to_card(target_card_data, types_to_add, duration)

func _add_types_to_card(target_card_data: CardData, types_string: String, duration: String):
	"""Add types/subtypes to a card with specified duration"""
	
	# Split types by space if multiple types specified
	var type_parts = types_string.split(" ")
	
	for type_part in type_parts:
		type_part = type_part.strip_edges()
		if type_part.is_empty():
			continue
		
		# Check if it's a main card type or subtype
		if CardData.isValidCardTypeString(type_part):
			# It's a main card type
			CardModifier.modify_card(target_card_data, "type", {"type": type_part}, duration)
		else:
			# It's a subtype
			CardModifier.modify_card(target_card_data, "subtype", {"subtype": type_part}, duration)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Types")

func get_description(parameters: Dictionary) -> String:
	var types = parameters.get("Types", "")
	var target = parameters.get("Target", "Self")
	return "Add " + types + " to " + target
