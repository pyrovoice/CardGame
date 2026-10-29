extends Effect
class_name DestroyEffect

## Moves the chosen cards to their owner's graveyard, allowing the normal death-replacement path.
## Affected$ Card.PlayerCreaturesAtSourceLocation is used by location-bound Countdown effects.

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var affected_cards: Array[CardData] = []
	if not targets.is_empty():
		affected_cards.assign(targets)
	elif parameters.get("Affected", "") == "Card.PlayerCreaturesAtSourceLocation":
		var location_index := GameZone.location_index_of(game_context.game_data.get_card_zone(source_card_data))
		if location_index < 0:
			return []
		for card_data in game_context.game_data.get_cards_in_zone(GameZone.combat_zone_for(location_index, true)):
			if card_data.playerControlled and card_data.hasType(CardData.CardType.CREATURE):
				affected_cards.append(card_data)
	else:
		affected_cards.assign(Effect.resolve_affected(parameters))

	for card_data in affected_cards:
		if not GameZone.is_in_play(game_context.game_data.get_card_zone(card_data)):
			continue
		var graveyard_zone := GameZone.e.GRAVEYARD_PLAYER if card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
		await game_context.execute_move_card(card_data, graveyard_zone)
	return affected_cards

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Affected") or parameters.has("ValidTargets") or parameters.has("Targets")

func get_description(parameters: Dictionary) -> String:
	return "Destroy " + str(parameters.get("Affected", parameters.get("ValidTargets", "target")))
