extends CardAbility
class_name ActivatedAbility

## Activated ability that players manually trigger
## Handles activation costs and player-initiated effects

var activation_costs: Array[Dictionary] = []  # Costs to activate (gold, sacrifice, tap, etc.)
var game_ref: WeakRef  # Reference to game node (for the refresh-on-turn-start listener)

func _init(p_owner: CardData, p_effect: EffectType.Type):
	super(p_owner)
	effect_type = p_effect
	exhausts_on_use = false  # Unlike triggered abilities, activating doesn't exhaust by default

## Game signal registration - unlike TriggeredAbility, this only ever listens for
## Beginning of Turn to auto-refresh. Activation itself is always player/AI-initiated,
## never signal-driven.

func register_to_game(game: Node) -> void:
	game_ref = weakref(game)
	if refreshes_on_turn_start and not game.is_connected("beginning_of_turn", _on_refresh_signal):
		game.connect("beginning_of_turn", _on_refresh_signal)

func unregister_from_game(game: Node) -> void:
	if game.is_connected("beginning_of_turn", _on_refresh_signal):
		game.disconnect("beginning_of_turn", _on_refresh_signal)

func _on_refresh_signal(_card_data: CardData = null) -> void:
	refresh()

## Builder methods

func with_activation_cost(cost_data: Dictionary) -> ActivatedAbility:
	"""Add an activation cost"""
	activation_costs.append(cost_data)
	return self

func has_activation_costs() -> bool:
	return not activation_costs.is_empty()

## Conversion methods for backward compatibility

func to_dictionary() -> Dictionary:
	"""Convert to dictionary format for backward compatibility"""
	return {
		"type": "ActivatedAbility",
		"effect_type": EffectType.type_to_string(effect_type),
		"effect_parameters": effect_parameters.duplicate(),
		"activation_costs": activation_costs.duplicate(),
		"targeting_requirements": targeting_requirements.duplicate()
	}

static func from_dictionary(owner: CardData, dict: Dictionary) -> ActivatedAbility:
	"""Create an ActivatedAbility from dictionary format"""
	var effect_str = dict.get("effect_type", "")
	var effect = EffectType.string_to_type(effect_str)
	
	var ability = ActivatedAbility.new(owner, effect)
	ability.effect_parameters = dict.get("effect_parameters", {})
	ability.activation_costs = dict.get("activation_costs", [])
	ability.targeting_requirements = dict.get("targeting_requirements", {})
	
	return ability
