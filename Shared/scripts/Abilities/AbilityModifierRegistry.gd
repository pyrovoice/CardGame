extends RefCounted
class_name AbilityModifierRegistry

## Global registry for ability modifiers (static effects that modify abilities)
## Modifiers are checked when abilities enter the trigger queue

static var _modifiers: Array[AbilityModifier] = []

static func register_modifier(modifier: AbilityModifier):
	"""Register a new ability modifier"""
	if not _modifiers.has(modifier):
		_modifiers.append(modifier)
		print("  📋 [REGISTRY] Registered modifier from ", modifier.source_card_data.cardName, " (", modifier.modifier_type, ")")

static func unregister_modifier(modifier: AbilityModifier):
	"""Unregister an ability modifier"""
	if _modifiers.has(modifier):
		_modifiers.erase(modifier)
		print("  📋 [REGISTRY] Unregistered modifier from ", modifier.source_card_data.cardName)

static func unregister_all_for_card(card_data: CardData):
	"""Unregister all modifiers from a specific card (e.g., when card leaves play)"""
	var to_remove: Array[AbilityModifier] = []
	for modifier in _modifiers:
		if modifier.source_card_data == card_data:
			to_remove.append(modifier)
	
	for modifier in to_remove:
		unregister_modifier(modifier)

static func apply_modifiers_to_effect(effect_type: String, effect_parameters: Dictionary, game_context: Game) -> Dictionary:
	"""
	Apply all applicable modifiers to an effect before it executes.
	Called when an ability enters the trigger queue.
	
	@param effect_type: String - The type of effect (e.g., "CreateToken", "DealDamage")
	@param effect_parameters: Dictionary - The original effect parameters
	@param game_context: Game - The game context
	@return: Dictionary - Modified effect parameters
	"""
	var modified_params = effect_parameters.duplicate()
	var applied_count = 0
	
	# Clean up invalid modifiers
	_cleanup_invalid_modifiers()
	
	# Apply each applicable modifier
	for modifier in _modifiers:
		if modifier.applies_to_ability(effect_type, modified_params, game_context):
			modified_params = modifier.apply_modifications(modified_params)
			applied_count += 1
	
	if applied_count > 0:
		print("  ✅ Applied ", applied_count, " modifier(s) to ", effect_type)
	
	return modified_params

static func _cleanup_invalid_modifiers():
	"""Remove modifiers whose source cards are no longer valid"""
	var to_remove: Array[AbilityModifier] = []
	
	for modifier in _modifiers:
		var source_card = modifier.source_card_data.get_card_object()
		if not source_card or not is_instance_valid(source_card):
			to_remove.append(modifier)
	
	for modifier in to_remove:
		unregister_modifier(modifier)

static func clear_all():
	"""Clear all registered modifiers (e.g., at game end)"""
	_modifiers.clear()
	print("  📋 [REGISTRY] Cleared all modifiers")

static func get_modifier_count() -> int:
	"""Get the number of registered modifiers"""
	return _modifiers.size()

static func debug_print_modifiers():
	"""Print all registered modifiers for debugging"""
	print("  📋 [REGISTRY] Active modifiers: ", _modifiers.size())
	for modifier in _modifiers:
		print("    - ", modifier.source_card_data.cardName, " (", modifier.modifier_type, ")")
