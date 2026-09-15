extends Keyword
class_name DefenderKeyword

## Elusive: this creature is placed at the end of the combat queue when fighting.
## Detected from card.text_box (not _keywords) for backward compatibility.

func get_keyword_name() -> String:
	return "Defender"

func should_register_for(card: CardData) -> bool:
	return card.text_box.contains("Defender")

func register_abilities(card: CardData) -> Array[CardAbility]:
	var replacement_effect := DefenderReplacementEffect.new(
		card,
		{"EventType": EffectType.Type.CREATURE_ATTACK, "ActiveZones": "Combat"},
		{}
	)
	var ability := ReplacementAbility.new(card, EffectType.Type.CREATURE_ATTACK, replacement_effect)
	var result: Array[CardAbility] = [ability]
	return result
