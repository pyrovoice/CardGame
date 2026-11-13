extends Effect
class_name AddPlayerPointsEffect

func execute(_parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	game_context.game_data.add_player_points(amount)
	return [source_card_data]