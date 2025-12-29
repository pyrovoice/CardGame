extends CardAbility
class_name StaticAbility

## Static ability that provides continuous effects while in play
## Example: "Other Goblins you control get +1/+1"
## Can also register ability modifiers (replacement effects like Goblin Warchief)

var affected_cards: Array[WeakRef] = []  # Cards currently affected by this ability
var registered_modifier: AbilityModifier = null  # Modifier registered in the global registry

func _init(p_owner: CardData, p_effect: EffectType.Type, game: Node = null):
	super(p_owner)
	effect_type = p_effect
	
	# Register modifier immediately if game is provided
	if game:
		apply_to_game(game)

func apply_to_game(game: Node):
	"""Apply the static effect and register modifiers"""
	_apply_static_effect(game)
	_register_modifier(game)

func remove_from_game(game: Node):
	"""Remove the static effect from all affected cards"""
	_remove_static_effect(game)
	_unregister_modifier()

func _register_modifier(game: Node):
	"""Register this ability as a modifier if it's a replacement effect"""
	# Check if this is a replacement effect (modifies other abilities)
	var replacement_conditions = effect_parameters.get("replacement_conditions", {})
	if replacement_conditions.is_empty():
		return
	
	var event_type = replacement_conditions.get("EventType", effect_parameters.get("event_type", ""))
	if event_type.is_empty():
		return
	
	# Determine modifier type from effect parameters
	var modifier_type = effect_parameters.get("Type", "")
	if modifier_type.is_empty():
		return
	
	# Create and register the modifier
	var conditions = replacement_conditions.duplicate()
	conditions["EventType"] = event_type
	
	var modifications = effect_parameters.duplicate()
	
	# Get the actual CardData from the WeakRef
	var owner = get_owner()
	if not owner:
		print("❌ [STATIC] Owner CardData no longer exists, cannot register modifier")
		return
	
	registered_modifier = AbilityModifier.new(
		owner,
		modifier_type,
		conditions,
		modifications
	)
	
	AbilityModifierRegistry.register_modifier(registered_modifier)
	print("  🔧 [STATIC] Registered modifier for ", EffectType.type_to_string(effect_type))

func _unregister_modifier():
	"""Unregister this ability's modifier"""
	if registered_modifier:
		AbilityModifierRegistry.unregister_modifier(registered_modifier)
		registered_modifier = null

func _apply_static_effect(game: Node):
	"""Apply this static ability's effect to valid targets"""
	# TODO: Implement based on effect_type and effect_parameters
	print("📊 [STATIC] Applying static effect: ", EffectType.type_to_string(effect_type))

func _remove_static_effect(game: Node):
	"""Remove this static ability's effect from all affected cards"""
	# TODO: Implement based on what was applied
	print("📊 [STATIC] Removing static effect: ", EffectType.type_to_string(effect_type))
	affected_cards.clear()

## Conversion methods for backward compatibility

func to_dictionary() -> Dictionary:
	"""Convert to dictionary format for backward compatibility"""
	return {
		"type": "StaticAbility",
		"effect_type": EffectType.type_to_string(effect_type),
		"effect_parameters": effect_parameters.duplicate(),
		"targeting_requirements": targeting_requirements.duplicate()
	}

static func from_dictionary(owner: CardData, dict: Dictionary) -> StaticAbility:
	"""Create a StaticAbility from dictionary format"""
	var effect_str = dict.get("effect_type", "")
	var effect = EffectType.string_to_type(effect_str)
	
	var ability = StaticAbility.new(owner, effect)
	ability.effect_parameters = dict.get("effect_parameters", {})
	ability.targeting_requirements = dict.get("targeting_requirements", {})
	
	return ability
