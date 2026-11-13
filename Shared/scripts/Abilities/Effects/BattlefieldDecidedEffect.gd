extends Effect
class_name BattlefieldDecidedEffect

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.get("CombatZone") is CombatZone and parameters.has("CapturedByPlayer")

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var combat_zone: CombatZone = parameters["CombatZone"]
	var location_index: int = game_context.game_view.get_combat_zones().find(combat_zone)
	if location_index < 0:
		return []
	var captured_by_player: bool = parameters["CapturedByPlayer"]
	var location_data: CombatLocationData = game_context.game_data.get_combat_zone_data(combat_zone)
	var permanents: Array[CardData] = []
	for player_side: bool in [true, false]:
		permanents.append_array(game_context.game_data.get_cards_in_zone(GameZone.camp_zone_for(location_index, player_side)))
		permanents.append_array(game_context.game_data.get_cards_in_zone(GameZone.combat_zone_for(location_index, player_side)))

	var outcome_parameters: Dictionary = {
		"Amount": 1,
		"Cause": EffectCause.Type.BATTLEFIELD_DECIDED,
		"CombatZone": combat_zone,
		"CapturedByPlayer": captured_by_player,
	}
	if captured_by_player:
		await EffectFactory.execute_effect(EffectType.Type.ADD_PLAYER_POINTS, outcome_parameters, source_card_data, game_context)
		location_data.player_capture_threshold.value += 5
		var lieutenant: LieutenantData = game_context.game_data.get_lieutenant_data_by_role(game_context._lieutenant_role_for_combat_zone(combat_zone))
		if lieutenant:
			lieutenant.reset_since_last_conquest()
	else:
		await EffectFactory.execute_effect(EffectType.Type.DAMAGE_PLAYER, outcome_parameters, source_card_data, game_context)
		var gold_parameters: Dictionary = outcome_parameters.duplicate()
		gold_parameters["Recipient"] = "Player"
		await EffectFactory.execute_effect(EffectType.Type.ADD_GOLD, gold_parameters, source_card_data, game_context)
		location_data.opponent_capture_threshold.value += 5

	game_context.game_data.reset_combat_zone_data(combat_zone)
	for permanent: CardData in permanents:
		var sacrifice_parameters: Dictionary = outcome_parameters.duplicate()
		sacrifice_parameters["TargetCard"] = permanent
		await EffectFactory.execute_effect(EffectType.Type.SACRIFICE, sacrifice_parameters, source_card_data, game_context)
	return [source_card_data]