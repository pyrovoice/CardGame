extends Effect
class_name AddKeywordEffect

## Effect that adds keyword abilities to creatures (formerly PumpAll)
## Expects targets to be pre-resolved and passed in parameters["Targets"]

func execute(parameters: Dictionary, _source_card_data: CardData, _game_context: Game):
	var keyword = parameters.get("KW", "")
	var duration = parameters.get("Duration", "Permanent")
	
	if keyword.is_empty():
		print("❌ No keyword specified for AddKeyword effect")
		return
	
	# Effects do not resolve/select targets; caller must provide them.
	var target_cards: Array = parameters.get("Targets", [])
	
	if target_cards.is_empty():
		print("⚠️ AddKeywordEffect missing pre-resolved Targets")
		return
	
	print("✨ Granting ", keyword, " to ", target_cards.size(), " creature(s) until ", duration)
	
	# Apply the keyword to each target
	for target_card in target_cards:
		_grant_keyword_to_card(target_card, keyword, duration)

func _grant_keyword_to_card(target_card_data: CardData, keyword: String, duration: String):
	"""Grant a keyword ability to a card"""
	CardModifier.modify_card(target_card_data, "keyword", {"keyword": keyword}, duration)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("KW")

func get_description(parameters: Dictionary) -> String:
	var keyword = parameters.get("KW", "")
	return "Grant " + keyword + " to targets"
