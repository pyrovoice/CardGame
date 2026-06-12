extends Effect
class_name AddTypeEffect

## Effect that adds types/subtypes to cards.
## Targets are resolved in order of priority:
##   1. Pre-resolved Targets in parameters (from AbilityManager targeting)
##   2. ValidCard$ filter applied to all in-play cards (random or player choice per Choice$)

func can_execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> bool:
	if parameters.has("ValidCard") and not parameters.has("Targets"):
		return _has_valid_affected_cards(parameters, game_context)
	return super.can_execute(parameters, source_card_data, game_context)

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var target_cards: Array[CardData] = []
	target_cards.assign(parameters.get("Targets", []))

	if target_cards.is_empty() and parameters.has("ValidCard"):
		target_cards = await get_affected_cards(parameters, source_card_data, game_context)

	if target_cards.is_empty():
		print("⚠️ AddTypeEffect: no targets resolved")
		return

	var types_to_add = parameters.get("Types", "")
	if types_to_add.is_empty():
		print("❌ No types specified for AddType effect")
		return

	var duration = parameters.get("Duration", "Permanent")

	for target_card_data in target_cards:
		_add_types_to_card(target_card_data, types_to_add, duration)

func _add_types_to_card(target_card_data: CardData, types_string: String, duration: String):
	"""Add types/subtypes to a card with specified duration"""

	var type_parts = types_string.split(" ")

	for type_part in type_parts:
		type_part = type_part.strip_edges()
		if type_part.is_empty():
			continue

		if CardData.isValidCardTypeString(type_part):
			CardModifier.modify_card(target_card_data, "type", {"type": type_part}, duration)
		else:
			CardModifier.modify_card(target_card_data, "subtype", {"subtype": type_part}, duration)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Types")

func get_description(parameters: Dictionary) -> String:
	var types = parameters.get("Types", "")
	var target = parameters.get("Target", "Self")
	return "Add " + types + " to " + target
