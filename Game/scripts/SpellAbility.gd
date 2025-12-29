extends CardAbility
class_name SpellAbility

## Spell ability that executes immediately when the spell is cast
## No trigger conditions - just direct effect execution

func _init(p_owner: CardData, p_effect: EffectType.Type):
	super(p_owner)
	effect_type = p_effect

## Conversion methods for backward compatibility

func to_dictionary() -> Dictionary:
	"""Convert to dictionary format for backward compatibility with AbilityManager"""
	return {
		"type": "SpellEffect",
		"effect_type": EffectType.type_to_string(effect_type),
		"effect_parameters": effect_parameters.duplicate(),
		"target_conditions": {},  # Spells don't filter trigger conditions
		"targeting_requirements": targeting_requirements.duplicate()
	}

static func from_dictionary(owner: CardData, dict: Dictionary) -> SpellAbility:
	"""Create a SpellAbility from dictionary format (for loading from JSON)"""
	var effect_str = dict.get("effect_type", "")
	var effect = EffectType.string_to_type(effect_str)
	
	var ability = SpellAbility.new(owner, effect)
	ability.effect_parameters = dict.get("parameters", {})
	ability.targeting_requirements = dict.get("targeting_requirements", {})
	
	return ability

func requires_target() -> bool:
	"""Check if this spell requires selecting a target"""
	# Spells with these effect types need targets
	var targeting_effects = [
		EffectType.Type.DEAL_DAMAGE,
		EffectType.Type.PUMP,
		EffectType.Type.DESTROY,
		EffectType.Type.BOUNCE,
		EffectType.Type.EXILE
	]
	return effect_type in targeting_effects
