extends ReplacementEffect
class_name DefenderReplacementEffect

## Defender: if an opposing creature attacks and no creature is there to block it,
## this creature is considered blocking it instead (the attack never reaches the location).

func applies_to_specific(effect_context: Dictionary, game_context: Game) -> bool:
	var attacking_card: CardData = effect_context.get("attacking_card")
	var combat_zone: CombatZone = effect_context.get("combat_zone")
	if not attacking_card or not combat_zone:
		return false

	# Only blocks the opposing side, and only at its own location
	if attacking_card.playerControlled == source_card_data.playerControlled:
		return false
	var defender_zone = game_context.game_view.get_zone_container(game_context.game_data.get_card_zone(source_card_data))
	return defender_zone == combat_zone

func apply_modification(effect_context: Dictionary, _game_context: Game) -> Dictionary:
	var modified_context = effect_context.duplicate()
	modified_context["event_was_replaced"] = true
	modified_context["blocking_card"] = source_card_data
	var attacker: CardData = effect_context.get("attacking_card")
	print("  🛡️ [DEFENDER] ", source_card_data.cardName, " blocks the unblocked attack from ", attacker.cardName if attacker else "unknown")
	return modified_context

func get_description() -> String:
	return source_card_data.cardName + " blocks unblocked attacks at its location (Defender)"
