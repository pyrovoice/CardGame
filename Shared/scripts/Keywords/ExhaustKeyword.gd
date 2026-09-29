extends Keyword
class_name ExhaustKeyword

## Exhaust: every ability on this card exhausts when used and only refreshes by Resting,
## not automatically at Beginning of Turn.

func get_keyword_name() -> String:
	return "Exhaust"

func should_register_for(card: CardData) -> bool:
	return card.text_box.contains("Exhaust")

func configure_existing_abilities(card: CardData) -> void:
	for ability in card.get_all_abilities():
		ability.exhausts_on_use = true
		ability.refreshes_on_turn_start = false
