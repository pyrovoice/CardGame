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
	exhausts_on_use = false  # Unlike triggered abilities, replacing doesn't exhaust by default
	if replacement_effect:
		replacement_effect.owning_ability = weakref(self)

func apply_to_game(game: Node):
	"""Register this replacement effect and the refresh-on-turn-start listener"""
	if replacement_effect:
		ReplacementEffectRegistry.register_replacement_effect(replacement_effect)
		print("  🔧 [REPLACEMENT] Registered ", EffectType.type_to_string(effect_type), " from ", get_owner().cardName)
	if refreshes_on_turn_start and not game.is_connected("beginning_of_turn", _on_refresh_signal):
		game.connect("beginning_of_turn", _on_refresh_signal)

func _on_refresh_signal(_card_data: CardData = null) -> void:
	refresh()

func remove_from_game(game: Node):
	"""Unregister this replacement effect and the refresh-on-turn-start listener"""
	if replacement_effect:
		ReplacementEffectRegistry.unregister_replacement_effect(replacement_effect)
		print("  🔧 [REPLACEMENT] Unregistered from ", get_owner().cardName if get_owner() else "unknown")
	if game.is_connected("beginning_of_turn", _on_refresh_signal):
		game.disconnect("beginning_of_turn", _on_refresh_signal)
