extends RefCounted
class_name ReplacementEffectRegistry

## Global registry for replacement effects
## Replacement effects are checked when effects are about to resolve

static var _replacement_effects: Array[ReplacementEffect] = []

static func register_replacement_effect(effect: ReplacementEffect):
	"""Register a new replacement effect"""
	if not _replacement_effects.has(effect):
		_replacement_effects.append(effect)
		print("  📋 [REGISTRY] Registered replacement effect from ", effect.source_card_data.cardName)

static func unregister_replacement_effect(effect: ReplacementEffect):
	"""Unregister a replacement effect"""
	if _replacement_effects.has(effect):
		_replacement_effects.erase(effect)
		print("  📋 [REGISTRY] Unregistered replacement effect from ", effect.source_card_data.cardName)

static func unregister_all_for_card(card_data: CardData):
	"""Unregister all replacement effects from a specific card (e.g., when card leaves play)"""
	var to_remove: Array[ReplacementEffect] = []
	for effect in _replacement_effects:
		if effect.source_card_data == card_data:
			to_remove.append(effect)
	
	for effect in to_remove:
		unregister_replacement_effect(effect)

static func apply_replacement_effects(effect_type: String, effect_parameters: Dictionary, game_context: Game) -> Dictionary:
	"""
	Apply all applicable replacement effects to an effect before it resolves.
	
	@param effect_type: String - The type of effect (e.g., "CreateToken", "DealDamage")
	@param effect_parameters: Dictionary - The original effect parameters
	@param game_context: Game - The game context
	@return: Dictionary - Modified effect parameters
	"""
	var modified_params = effect_parameters.duplicate()
	var applied_count = 0
	
	# Note: Cleanup is NOT done here - replacement effects are only removed when
	# their source card explicitly leaves play (via remove_from_game)
	
	# Apply each applicable replacement effect
	for effect in _replacement_effects:
		if effect.applies_to(effect_type, modified_params, game_context):
			modified_params = effect.apply_modification(modified_params, game_context)
			applied_count += 1
	
	if applied_count > 0:
		print("  ✅ Applied ", applied_count, " replacement effect(s) to ", effect_type)
	
	return modified_params

static func _cleanup_invalid_effects(game_context: Game):
	"""Remove replacement effects whose source cards are no longer active in game data"""
	var to_remove: Array[ReplacementEffect] = []
	
	for effect in _replacement_effects:
		if not effect.source_card_data:
			print("  🐛 [REGISTRY DEBUG] Effect has no source_card_data")
			to_remove.append(effect)
			continue
		var zone = game_context.game_data.get_card_zone(effect.source_card_data)
		print("  🐛 [REGISTRY DEBUG] Checking ", effect.source_card_data.cardName, " zone: ", zone, " (", GameZone.e.keys()[zone] if zone < GameZone.e.size() else "INVALID", ")")
		if zone == GameZone.e.UNKNOWN:
			print("  🐛 [REGISTRY DEBUG] Removing effect from ", effect.source_card_data.cardName, " - zone is UNKNOWN")
			to_remove.append(effect)
	
	for effect in to_remove:
		unregister_replacement_effect(effect)

static func clear_all():
	"""Clear all registered replacement effects (e.g., at game end)"""
	_replacement_effects.clear()
	print("  📋 [REGISTRY] Cleared all replacement effects")

static func get_effect_count() -> int:
	"""Get the number of registered replacement effects"""
	return _replacement_effects.size()

static func debug_print_effects():
	"""Print all registered replacement effects for debugging"""
	print("  📋 [REGISTRY] Active replacement effects: ", _replacement_effects.size())
	for effect in _replacement_effects:
		print("    - ", effect.source_card_data.cardName, ": ", effect.get_description())
