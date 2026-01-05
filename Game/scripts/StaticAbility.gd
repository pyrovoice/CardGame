extends CardAbility
class_name StaticAbility

## Static ability that provides continuous effects while in play (S: effects)
## Example: "Other Goblins you control get +1/+1"
## Note: Use ReplacementAbility for R: effects that modify how effects resolve

var affected_cards: Array[WeakRef] = []  # Cards currently affected by this ability

func _init(p_owner: CardData, p_effect: EffectType.Type):
	super(p_owner)
	effect_type = p_effect

func apply_to_game(game: Node):
	"""Apply this static ability to the game (for future continuous effects)"""
	# Future: Apply continuous modifications to other cards
	pass

func remove_from_game(game: Node):
	"""Remove this static ability from the game"""
	# Future: Remove continuous modifications
	pass

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
