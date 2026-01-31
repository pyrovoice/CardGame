extends CardAbility
class_name ReplacementAbility

## Replacement ability that modifies how effects resolve (R: effects)
## Example: "If one or more Goblin token would be created, create that many plus one instead"
## Registers a ReplacementEffect that intercepts and modifies effects as they resolve

var replacement_effect: ReplacementEffect = null  # The replacement effect implementation

func _init(p_owner: CardData, p_effect: EffectType.Type, p_replacement_effect: ReplacementEffect):
	super(p_owner)
	effect_type = p_effect
	replacement_effect = p_replacement_effect

func apply_to_game(game: Node):
	"""Register this replacement effect"""
	if replacement_effect:
		ReplacementEffectRegistry.register_replacement_effect(replacement_effect)
		print("  🔧 [REPLACEMENT] Registered ", EffectType.type_to_string(effect_type), " from ", get_owner().cardName)

func remove_from_game(game: Node):
	"""Unregister this replacement effect"""
	if replacement_effect:
		ReplacementEffectRegistry.unregister_replacement_effect(replacement_effect)
		print("  🔧 [REPLACEMENT] Unregistered from ", get_owner().cardName if get_owner() else "unknown")
