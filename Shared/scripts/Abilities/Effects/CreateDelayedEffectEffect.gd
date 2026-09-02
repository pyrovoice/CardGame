extends Effect
class_name CreateDelayedEffectEffect

## Effect that creates a delayed/orphaned triggered ability
## The ability is not attached to any card and persists independently
## Used for effects like "Sacrifice at end of turn" from spells

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	print("⏰ [CREATE DELAYED EFFECT] Creating delayed effect from ", source_card_data.cardName)
	
	# trigger_event, nested_effect_type, nested_parameters, and targets are already parsed by _parse_parameters()
	if nested_effect_type == EffectType.Type.NONE:
		push_error("CreateDelayedEffect: No nested effect specified")
		return []
	
	# Build effect parameters for the delayed effect
	var effect_parameters: Dictionary = nested_parameters.duplicate()
	
	# Handle spell targets - if this spell targeted something, pass it to the delayed effect
	if targets.size() > 0:
		if targets.size() == 1:
			effect_parameters["TargetCard"] = targets[0]
		else:
			effect_parameters["TargetCards"] = targets
	
	print("  Trigger Event: ", trigger_event)
	print("  Wrapped Effect: ", EffectType.type_to_string(nested_effect_type))
	print("  Effect Parameters: ", effect_parameters)
	
	# Create the orphaned triggered ability
	var orphaned_ability = TriggeredAbility.new(
		source_card_data,
		trigger_event,
		nested_effect_type
	)
	orphaned_ability.effect_parameters = effect_parameters
	orphaned_ability.one_shot = true
	orphaned_ability.cleanup_at_end_of_turn = true
	
	game_context.register_orphaned_ability(orphaned_ability)
	
	print("✅ [CREATE DELAYED EFFECT] Registered: ", EffectType.type_to_string(nested_effect_type), " at ", trigger_event)
	print("  Will auto-cleanup at end of turn if not fired")
	return []

func validate_parameters(parameters: Dictionary) -> bool:
	# Must have pre-parsed nested effect type
	return parameters.has("NestedEffectType")

func get_description(parameters: Dictionary) -> String:
	var nested_effect_type = parameters.get("NestedEffectType", EffectType.Type.NONE)
	var trigger_event = parameters.get("TriggerEvent", TriggeredAbility.GameEventType.END_OF_TURN)
	return "Create delayed " + EffectType.type_to_string(nested_effect_type) + " at " + str(trigger_event)
