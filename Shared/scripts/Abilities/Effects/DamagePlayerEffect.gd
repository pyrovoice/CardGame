extends Effect
class_name DamagePlayerEffect

func execute(_parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	game_context.game_data.damage_player(amount)
	return [source_card_data]