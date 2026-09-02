extends ReplacementEffect
class_name ReplaceEventEffect

## Generic full-substitution replacement effect: cancels the original event and
## executes the ReplaceWith$ SVar chain instead.
## Example: "If I would die, I split into Upper half and Lower half instead"
## Works for any Event$ type (Death, DealDamage, etc.) — not specific to death.

func apply_modification(effect_context: Dictionary, _game_context: Game) -> Dictionary:
	"""Cancel the original event and mark it as replaced; the caller executes the SVar chain."""
	var modified_context = effect_context.duplicate()
	
	modified_context["event_was_replaced"] = true
	
	print("  🔄 [REPLACEMENT] ", source_card_data.cardName, " event replaced by replacement effect")
	
	# The actual replacement effect (creating tokens, etc.) is handled by the SVar chain
	# which is stored in modifications["effect_name"]
	var replacement_svar = modifications.get("effect_name", "")
	if not replacement_svar.is_empty():
		modified_context["replacement_svar"] = replacement_svar
	
	return modified_context

func applies_to_specific(effect_context: Dictionary, _game_context: Game) -> bool:
	"""Check ValidCard conditions against the event's source card"""
	var valid_card = conditions.get("ValidCard", "Any")
	if valid_card == "Any":
		return true
	
	# Get the card the event is happening to (e.g. the dying card for a Death event)
	var event_card = effect_context.get("dying_card")
	if not event_card:
		return false
	
	# Check if ValidCard condition matches
	# For "Card.Self", check if the event card is the source card
	if valid_card == "Card.Self":
		return event_card == source_card_data
	
	# Parse more complex conditions like "Card.YouCtrl+Creature.Zombie"
	var condition_parts = valid_card.split("+")
	
	for single_condition in condition_parts:
		single_condition = single_condition.strip_edges()
		
		if single_condition == "Card.Self":
			if event_card != source_card_data:
				return false
		elif single_condition == "Card.YouCtrl":
			if not event_card.playerControlled:
				return false
		elif single_condition.begins_with("Creature."):
			var required_subtype = single_condition.substr(9)
			if not event_card.hasType(CardData.CardType.CREATURE):
				return false
			if not event_card.hasSubtype(required_subtype):
				return false
	
	return true

func validate_parameters(parameters: Dictionary) -> bool:
	# Full-substitution replacements need an effect_name (the SVar to execute)
	return parameters.has("effect_name")

func get_description() -> String:
	var replacement_svar = modifications.get("effect_name", "")
	return "Replace with: " + replacement_svar
