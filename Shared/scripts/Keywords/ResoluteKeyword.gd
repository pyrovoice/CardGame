extends Keyword
class_name ResoluteKeyword

func get_keyword_name() -> String:
	return "Resolute"

func should_register_for(card: CardData) -> bool:
	return card.has_keyword("Resolute") or card.text_box.contains("Resolute")

func register_abilities(card: CardData) -> Array[CardAbility]:
	card.add_keyword("Resolute")
	var replacement := ResoluteReplacementEffect.new(
		card,
		{"EventType": EffectType.Type.SACRIFICE, "ActiveZones": "Battlefield"},
		{}
	)
	var result: Array[CardAbility] = [ReplacementAbility.new(card, EffectType.Type.SACRIFICE, replacement)]
	return result

func on_apply(card: CardData, game: Game) -> void:
	for ability: ReplacementAbility in card.replacement_abilities:
		if ability.replacement_effect is ResoluteReplacementEffect:
			ability.apply_to_game(game)
			return
	var replacement := ResoluteReplacementEffect.new(
		card,
		{"EventType": EffectType.Type.SACRIFICE, "ActiveZones": "Battlefield"},
		{}
	)
	var ability := ReplacementAbility.new(card, EffectType.Type.SACRIFICE, replacement)
	card.add_ability(ability)
	ability.apply_to_game(game)