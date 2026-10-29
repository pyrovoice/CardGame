extends Effect
class_name CountdownTickEffect

## Decrements a card's Countdown charge counter by 1 each Beginning of Turn.
## Attached as a universal trigger on every card (see CardLoader.duplicateCardScript);
## only fires while countdown > 0 (gated by the Self.HasCountdown+Active trigger condition).
## When the counter reaches 0, fires COUNTDOWN_REACHED_ZERO first - while the card is still in
## play - so the card's own T:Mode$ CountdownZero ability can run its custom effect using the
## card's location/zone, then the card is sacrificed.

func execute(_parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	if source_card_data.countdown <= 0:
		return []
	
	print("⏬ [COUNTDOWN] ", source_card_data.cardName, " countdown: ", source_card_data.countdown, " → ", source_card_data.countdown - 1)
	source_card_data.countdown -= 1
	source_card_data.dirty_data.emit()
	
	if source_card_data.countdown <= 0:
		print("💀 [COUNTDOWN] ", source_card_data.cardName, " countdown reached zero")
		await game_context.emit_game_event(TriggeredAbility.GameEventType.COUNTDOWN_REACHED_ZERO, source_card_data)
		game_context.defer_countdown_sacrifice(source_card_data)
	
	return []

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(_parameters: Dictionary) -> String:
	return "Remove 1 Countdown charge; resolve its effect and sacrifice when depleted"
