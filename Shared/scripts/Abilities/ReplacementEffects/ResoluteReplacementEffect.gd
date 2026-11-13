extends ReplacementEffect
class_name ResoluteReplacementEffect

func applies_to_specific(effect_context: Dictionary, _game_context: Game) -> bool:
	return (
		not effect_context.get("event_was_replaced", false)
		and effect_context.get("TargetCard") == source_card_data
		and effect_context.get("Cause", EffectCause.Type.UNSPECIFIED) == EffectCause.Type.BATTLEFIELD_DECIDED
		and source_card_data.has_keyword("Resolute")
	)

func apply_modification(effect_context: Dictionary, _game_context: Game) -> Dictionary:
	var modified_context: Dictionary = effect_context.duplicate()
	for temporary_effect: TemporaryEffect in source_card_data.temporary_effects.duplicate():
		if temporary_effect.matches_keyword("Resolute"):
			source_card_data.clear_temporary_effect(temporary_effect)
	source_card_data.remove_keyword("Resolute")
	source_card_data.dirty_data.emit()
	modified_context["event_was_replaced"] = true
	return modified_context

func get_description() -> String:
	return "If this permanent would be sacrificed when its battlefield is Decided, it loses Resolute instead."