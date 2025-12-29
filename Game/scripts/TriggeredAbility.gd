extends CardAbility
class_name TriggeredAbility

## Triggered ability that automatically responds to game events
## Registers itself to game signals when enabled

enum GameEventType {
	ATTACK_DECLARED,      # When this or another card attacks
	CARD_DIED,            # When this or another card dies
	CARD_ENTERED_PLAY,    # When this or another card enters play
	DAMAGE_DEALT,         # When damage is dealt
	TURN_STARTED,         # At the start of a turn
	SPELL_CAST,           # When a spell is cast
	END_OF_TURN,          # At end of turn
	BEGINNING_OF_TURN     # At beginning of turn
}

# Mapping from GameEventType to game.gd signal names
const EVENT_TO_SIGNAL = {
	GameEventType.ATTACK_DECLARED: "attack_declared",
	GameEventType.CARD_DIED: "card_died",
	GameEventType.CARD_ENTERED_PLAY: "card_entered_play",
	GameEventType.DAMAGE_DEALT: "damage_dealt",
	GameEventType.TURN_STARTED: "turn_started",
	GameEventType.SPELL_CAST: "spell_cast",
	GameEventType.END_OF_TURN: "end_of_turn",
	GameEventType.BEGINNING_OF_TURN: "beginning_of_turn"
}

var game_event_trigger: GameEventType
var game_ref: WeakRef  # Reference to game node

func _init(p_owner: CardData, p_trigger: GameEventType, p_effect: EffectType.Type, game: Node = null):
	super(p_owner)
	game_event_trigger = p_trigger
	effect_type = p_effect
	
	# Connect to game signals immediately if game is provided
	if game:
		register_to_game(game)

func register_to_game(game: Node):
	"""Register this ability to listen to the appropriate game signal"""
	game_ref = weakref(game)
	
	var signal_name = EVENT_TO_SIGNAL.get(game_event_trigger, "")
	if signal_name.is_empty():
		print("❌ Unknown trigger type for ability: ", game_event_trigger)
		return
	
	# Check if signal exists on game node
	if not game.has_signal(signal_name):
		print("❌ Game node missing signal: ", signal_name)
		return
	
	# Connect to the signal
	if not game.is_connected(signal_name, _on_game_event):
		game.connect(signal_name, _on_game_event)
		
		var owner = get_owner()
		var card_name = owner.cardName if owner else "Unknown"
		print("📡 [ABILITY REGISTER] ", card_name, " listening to '", signal_name, "'")

func unregister_from_game(game: Node):
	"""Disconnect from game signal (called when card leaves play or is destroyed)"""
	var signal_name = EVENT_TO_SIGNAL.get(game_event_trigger, "")
	if signal_name.is_empty():
		return
	
	if game.has_signal(signal_name) and game.is_connected(signal_name, _on_game_event):
		game.disconnect(signal_name, _on_game_event)
		
		var owner = get_owner()
		var card_name = owner.cardName if owner else "Unknown"
		print("📡 [ABILITY UNREGISTER] ", card_name, " from '", signal_name, "'")

## Signal callback

func _on_game_event(event_card_data: CardData = null, context: Dictionary = {}):
	"""Called when the relevant game event fires"""
	var owner = get_owner()
	if not owner:
		return  # Owner was destroyed
	
	var game = game_ref.get_ref() if game_ref else null
	if not game:
		return  # Game was destroyed (shouldn't happen)
	
	# Check if trigger conditions are met
	if not _check_trigger_conditions(owner, event_card_data, context, game):
		return
	
	# Add to trigger queue
	var ability_desc = event_to_string(game_event_trigger) + " -> " + EffectType.type_to_string(effect_type)
	print("⚡ [TRIGGER] ", owner.cardName, " ability triggered: ", ability_desc)
	
	game.trigger_queue.add_trigger(owner, self, context)

func _check_trigger_conditions(owner: CardData, event_card_data: CardData, context: Dictionary, game: Node) -> bool:
	"""Check if the trigger conditions for this ability are met"""
	# Check "Self" condition - ability only triggers for this card
	if trigger_conditions.get("Self", false):
		if event_card_data != owner:
			return false
	
	# Check "ValidCards" condition - filter what cards trigger this
	var valid_cards_filter = trigger_conditions.get("ValidCards", "")
	if valid_cards_filter != "":
		# TODO: Implement card filtering based on ValidCards
		# For now, accept all
		pass
	
	return true

## Helper methods

static func event_to_string(event: GameEventType) -> String:
	"""Convert GameEventType to string"""
	match event:
		GameEventType.ATTACK_DECLARED:
			return "AttackDeclared"
		GameEventType.CARD_DIED:
			return "CardDied"
		GameEventType.CARD_ENTERED_PLAY:
			return "CardEnteredPlay"
		GameEventType.DAMAGE_DEALT:
			return "DamageDealt"
		GameEventType.TURN_STARTED:
			return "TurnStarted"
		GameEventType.SPELL_CAST:
			return "SpellCast"
		GameEventType.END_OF_TURN:
			return "EndOfTurn"
		GameEventType.BEGINNING_OF_TURN:
			return "BeginningOfTurn"
	return "Unknown"

static func string_to_event(event_str: String) -> GameEventType:
	"""Convert string to GameEventType"""
	match event_str:
		"AttackDeclared":
			return GameEventType.ATTACK_DECLARED
		"CardDied":
			return GameEventType.CARD_DIED
		"CardEnteredPlay", "Enters":
			return GameEventType.CARD_ENTERED_PLAY
		"DamageDealt":
			return GameEventType.DAMAGE_DEALT
		"TurnStarted":
			return GameEventType.TURN_STARTED
		"SpellCast":
			return GameEventType.SPELL_CAST
		"EndOfTurn":
			return GameEventType.END_OF_TURN
		"BeginningOfTurn":
			return GameEventType.BEGINNING_OF_TURN
	return GameEventType.CARD_ENTERED_PLAY  # Default

## Conversion methods for backward compatibility

func to_dictionary() -> Dictionary:
	"""Convert to dictionary format for backward compatibility"""
	return {
		"type": "TriggeredAbility",
		"trigger": event_to_string(game_event_trigger),
		"effect_type": EffectType.type_to_string(effect_type),
		"effect_parameters": effect_parameters.duplicate(),
		"trigger_conditions": trigger_conditions.duplicate(),
		"targeting_requirements": targeting_requirements.duplicate()
	}

static func from_dictionary(owner: CardData, dict: Dictionary) -> TriggeredAbility:
	"""Create a TriggeredAbility from dictionary format"""
	var trigger_str = dict.get("trigger", "")
	var trigger_event = string_to_event(trigger_str)
	
	var effect_str = dict.get("effect_type", "")
	var effect = EffectType.string_to_type(effect_str)
	
	var ability = TriggeredAbility.new(owner, trigger_event, effect)
	ability.effect_parameters = dict.get("effect_parameters", {})
	ability.trigger_conditions = dict.get("trigger_conditions", {})
	ability.targeting_requirements = dict.get("targeting_requirements", {})
	
	return ability
