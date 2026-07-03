extends Keyword
class_name FleetingKeyword

## Fleeting: this card is discarded at the end of your turn.

func get_keyword_name() -> String:
	return "fleeting"

func register_abilities(card: CardData) -> Array[CardAbility]:
	var ability := TriggeredAbility.new(
		card,
		TriggeredAbility.GameEventType.END_OF_TURN,
		EffectType.Type.MOVE_CARD
	)
	ability.effect_parameters = {
		"Origin":      "Hand.Controller",
		"Destination": "Graveyard.Controller",
		"Defined":     "Self",
	}
	ability.trigger_conditions = {
		TriggeredAbility.TriggerCondition.TRIGGER_ZONES: GameZone.parse_trigger_zones("Hand"),
	}
	var result: Array[CardAbility] = [ability]
	return result
