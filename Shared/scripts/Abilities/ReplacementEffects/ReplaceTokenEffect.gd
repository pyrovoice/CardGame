extends ReplacementEffect
class_name ReplaceTokenEffect

## Replacement effect that modifies token creation
## Example: "If one or more Goblin tokens would be created, create that many plus one instead"

func apply_modification(effect_context: Dictionary, _game_context: Game) -> Dictionary:
	var modified_context = effect_context.duplicate()
	
	var modification_type = modifications.get("Type", "")
	
	match modification_type:
		"AddToken":
			# Add additional tokens to be created
			var amount_to_add = int(modifications.get("Amount", "0"))
			var current_amount = modified_context.get("tokens_to_create", 1)
			modified_context["tokens_to_create"] = current_amount + amount_to_add
			print("  📝 [REPLACEMENT] ", source_card_data.cardName, " adds ", amount_to_add, " token(s). Total: ", modified_context["tokens_to_create"])
		_:
			print("  ⚠️ Unknown replacement type: ", modification_type)
	
	return modified_context

func applies_to_specific(effect_context: Dictionary, _game_context: Game) -> bool:
	"""Check token-specific conditions"""
	var valid_token = conditions.get("ValidToken", "Any")
	if valid_token == "Any":
		return true
	
	# Need token data to check conditions
	var token_script = effect_context.get("TokenScript", "")
	if token_script.is_empty():
		return false
	
	var token_data = CardLoaderAL.getCardByName(token_script)
	if not token_data:
		return false
	
	# Parse condition like "Card.YouCtrl+Creature.Goblin"
	var condition_parts = valid_token.split("+")
	
	for single_condition in condition_parts:
		single_condition = single_condition.strip_edges()
		
		if single_condition == "Card.YouCtrl":
			# Token controller check
			continue
		elif single_condition.begins_with("Creature."):
			var required_subtype = single_condition.substr(9)
			
			if not token_data.hasType(CardData.CardType.CREATURE):
				return false
			
			if not token_data.hasSubtype(required_subtype):
				return false
	
	return true

func validate_parameters(parameters: Dictionary) -> bool:
	# Must have Type parameter
	if not parameters.has("Type"):
		return false
	
	# Must have Amount for AddToken type
	if parameters.get("Type") == "AddToken" and not parameters.has("Amount"):
		return false
	
	return true

func get_description() -> String:
	var modification_type = modifications.get("Type", "")
	match modification_type:
		"AddToken":
			var amount = modifications.get("Amount", "0")
			return "Create " + amount + " additional token(s)"
		_:
			return "Unknown replacement effect"
