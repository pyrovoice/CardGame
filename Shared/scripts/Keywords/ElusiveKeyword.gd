extends Keyword
class_name ElusiveKeyword

## Elusive: this creature is placed at the end of the combat queue when fighting.
## Detected from card.text_box (not _keywords) for backward compatibility.

func get_keyword_name() -> String:
	return "Elusive"

func should_register_for(card: CardData) -> bool:
	return card.text_box.contains("Elusive")

func register_abilities(card: CardData) -> Array[CardAbility]:
	var ability := TriggeredAbility.new(
		card,
		TriggeredAbility.GameEventType.ATTACK_DECLARED,
		EffectType.Type.SWITCH_POSITIONS
	)
	ability.effect_parameters = {
		"SwitchWith":       "LastOther",
		"OnlySameLocation": true,
	}
	ability.trigger_conditions = {
		TriggeredAbility.TriggerCondition.VALID_CARD:    "Card.Self",
		TriggeredAbility.TriggerCondition.TRIGGER_ZONES: GameZone.parse_trigger_zones("Combat"),
	}
	var result: Array[CardAbility] = [ability]
	return result
