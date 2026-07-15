extends Keyword
class_name RecycleKeyword

## Recycle X: Exile X cards from your graveyard at random.
## Used as "You may Recycle X. If you do, [effect]" or as an additional cost.
## The execution logic lives in RecycleEffect; this class provides keyword detection.

func get_keyword_name() -> String:
	return "Recycle"

func should_register_for(card: CardData) -> bool:
	return "Recycle" in card.text_box

func register_abilities(card: CardData) -> Array[CardAbility]:
	return []  # No persistent abilities; Recycle fires through RecycleEffect
