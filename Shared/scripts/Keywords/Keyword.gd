extends RefCounted
class_name Keyword

## Base class for keywords that carry game logic.
## Mirror of Effect.gd — subclasses override on_apply() and/or register_abilities().
##
## Registering a new keyword:
##   1. Create MyKeyword.gd extending Keyword in Shared/scripts/Keywords/
##   2. Override get_keyword_name(), on_apply(), register_abilities() as needed
##   3. Add _register(MyKeyword.new()) in KeywordRegistry._register_all()

## The exact keyword string as it appears in card text and _keywords arrays.
func get_keyword_name() -> String:
	push_error("Keyword.get_keyword_name() must be implemented by subclass")
	return ""

## Called when this keyword is dynamically granted to a card during gameplay
## (via CardModifier.modify_card with a Game context).
## Override to implement on-apply side-effects (power boost, control switch, etc.).
func on_apply(card: CardData, game: Game) -> void:
	pass

## Called at card-load time for cards whose base definition includes this keyword.
## Return any abilities (TriggeredAbility, StaticAbility…) to be added to the card.
## Replaces the old _add_elusive_ability / _add_fleeting_ability pattern in CardLoader.
func register_abilities(card: CardData) -> Array[CardAbility]:
	return []

## Override to detect this keyword from sources other than card._keywords.
## Default: check whether get_keyword_name() is in card._keywords.
## Example override: ElusiveKeyword checks card.text_box instead.
func should_register_for(card: CardData) -> bool:
	return get_keyword_name() in card._keywords
