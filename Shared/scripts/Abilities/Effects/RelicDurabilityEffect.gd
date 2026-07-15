extends Effect
class_name RelicDurabilityEffect

## Decrements the durability of a Relic card by 1.
## If durability reaches 0, the card is sacrificed.
## This effect is attached as a universal BEGINNING_OF_TURN trigger on every card,
## but only fires when the card currently has the Relic type.

func execute(_parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# Re-check type at resolution time: the card may have lost the Relic type between
	# trigger and resolution (e.g., another effect removed the type this same turn).
	if not source_card_data.hasType(CardData.CardType.RELIC):
		return []
	
	source_card_data.durability -= 1
	
	if source_card_data.durability <= 0:
		print("💥 [RELIC] ", source_card_data.cardName, " durability depleted — sacrificing")
		var sacrifice = SacrificeEffect.new()
		await sacrifice.execute({"Defined": "Self"}, source_card_data, game_context)

	return []

func validate_parameters(_parameters: Dictionary) -> bool:
	return true

func get_description(_parameters: Dictionary) -> String:
	return "Lose 1 durability; sacrifice if depleted"
