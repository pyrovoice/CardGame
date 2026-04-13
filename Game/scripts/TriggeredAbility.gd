extends CardAbility
class_name TriggeredAbility

## Triggered ability that automatically responds to game events
## Registers itself to game signals when enabled
##
## ORPHANED ABILITIES (Delayed Effects):
## For effects like "Sacrifice at end of turn" that persist after the spell resolves:
##
## # In a spell effect:
## var returned_card: CardData = # ... card that was returned to play
##
## # Create orphaned ability
## var sacrifice_ability = TriggeredAbility.new(
##     source_card_data,  # The spell that created this
##     TriggeredAbility.GameEventType.END_OF_TURN,
##     EffectType.Type.SACRIFICE
## )
## sacrifice_ability.effect_parameters = {"TargetCard": returned_card}
## sacrifice_ability.one_shot = true  # Remove after firing once
## sacrifice_ability.cleanup_at_end_of_turn = true  # Backup cleanup
## game_context.register_orphaned_ability(sacrifice_ability)
##
## The ability will:
## - Register to end_of_turn signal
## - Trigger when signal fires
## - Add to queue and resolve (even if spell is in graveyard)
## - Auto-remove after triggering (one_shot = true)

enum GameEventType {
	ATTACK_DECLARED,      # When this or another card attacks
	CARD_DIED,            # When this or another card dies
	CARD_ENTERED_PLAY,    # When this or another card enters play
	CARD_DRAWN,           # When a card is drawn
	CARD_CHANGED_ZONES,   # When a card changes zones (origin/destination)
	DAMAGE_DEALT,         # When damage is dealt
	TURN_STARTED,         # At the start of a turn
	SPELL_CAST,           # When a spell is cast
	END_OF_TURN,          # At end of turn
	BEGINNING_OF_TURN,    # At beginning of turn
	END_OF_TURN_CLEANUP,  # After end of turn, for cleanup (temporary effects, orphaned abilities)
	STRIKE,               # Creature strikes
	CARD_RECYCLED         # When a card is recycled from hand
}

enum TriggerCondition {
	ORIGIN,                  # Origin zone for movement triggers
	DESTINATION,             # Destination zone for movement triggers
	VALID_CARD,              # Filter for which cards trigger this ability
	VALID_ACTIVATING_PLAYER, # Filter for which player's actions trigger this
	TRIGGER_ZONES,           # Zones where this ability is active
	PHASE,                   # Phase condition for turn-based triggers
	CONDITION                # Additional conditions for triggering
}

# Mapping from GameEventType to game.gd signal names
const EVENT_TO_SIGNAL = {
	GameEventType.ATTACK_DECLARED: "attack_declared",
	GameEventType.CARD_DIED: "card_died",
	GameEventType.CARD_ENTERED_PLAY: "card_entered_play",
	GameEventType.CARD_DRAWN: "card_drawn",
	GameEventType.CARD_CHANGED_ZONES: "card_changed_zones",
	GameEventType.DAMAGE_DEALT: "damage_dealt",
	GameEventType.TURN_STARTED: "turn_started",
	GameEventType.SPELL_CAST: "spell_cast",
	GameEventType.END_OF_TURN: "end_of_turn",
	GameEventType.BEGINNING_OF_TURN: "beginning_of_turn",
	GameEventType.END_OF_TURN_CLEANUP: "end_of_turn_cleanup",
	GameEventType.STRIKE: "strike"
}

var game_event_trigger: GameEventType
var game_ref: WeakRef  # Reference to game node
var trigger_conditions: Dictionary = {}  # Conditions that must be met (ValidCards, Self, etc.)

# Orphaned ability flags (for abilities not attached to cards)
var one_shot: bool = false  # If true, ability auto-removes after triggering once
var cleanup_at_end_of_turn: bool = false  # If true, ability is removed at end of turn regardless

func _init(p_owner: CardData, p_trigger: GameEventType, p_effect: EffectType.Type, game: Node = null):
	super(p_owner)
	game_event_trigger = p_trigger
	effect_type = p_effect
	
	# Connect to game signals immediately if game is provided
	if game:
		register_to_game(game)

## Builder methods

func with_trigger_condition(condition_key: String, condition_value) -> TriggeredAbility:
	"""Add a trigger condition (ValidCards, Self, etc.)"""
	trigger_conditions[condition_key] = condition_value
	return self

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

func unregister_from_game(game: Node):
	"""Disconnect from game signal (called when card leaves play or is destroyed)"""
	var signal_name = EVENT_TO_SIGNAL.get(game_event_trigger, "")
	if signal_name.is_empty():
		return
	
	if game.has_signal(signal_name) and game.is_connected(signal_name, _on_game_event):
		game.disconnect(signal_name, _on_game_event)
		
		var owner = get_owner()
		var card_name = owner.cardName if owner else "Unknown"

## Signal callback

func _on_game_event(event_card_data: CardData = null, from_zone = null, to_zone = null):
	"""Called when the relevant game event fires
	
	Note: Some signals emit additional parameters (e.g., card_changed_zones emits from_zone and to_zone).
	These are used for Origin$ and Destination$ condition checking.
	"""
	var owner = get_owner()
	if not owner:
		return  # Owner was destroyed
	
	var game = game_ref.get_ref() if game_ref else null
	if not game:
		return  # Game was destroyed (shouldn't happen)
	
	# Check if trigger conditions are met
	if not _check_trigger_conditions(owner, event_card_data, game, from_zone, to_zone):
		return
	
	# Add to trigger queue with event context
	var ability_desc = event_to_string(game_event_trigger) + " -> " + EffectType.type_to_string(effect_type)
	print("⚡ [TRIGGER] ", owner.cardName, " ability triggered: ", ability_desc)
	
	# Debug logging for Grave Whisperer Elusive
	if owner.cardName == "Grave Whisperer" and game_event_trigger == GameEventType.CARD_CHANGED_ZONES:
		var from_str = GameZone.get_as_string(from_zone) if from_zone != null else "null"
		var to_str = GameZone.get_as_string(to_zone) if to_zone != null else "null"
		var event_card_name = event_card_data.cardName if event_card_data else "null"
		print("    🔍 [ELUSIVE TRIGGERED] Zone change: ", from_str, " → ", to_str, " (event card: ", event_card_name, ")")
	
	# Package the event context
	var event_context = {}
	if event_card_data:
		event_context["TriggeredCardData"] = event_card_data
	
	game.trigger_queue.add_resolvable(owner, self, event_context)
	
	# If this is a one-shot orphaned ability, unregister it after triggering
	# (it will still resolve from the queue, but won't trigger again)
	if one_shot and self in game.orphaned_abilities:
		game.unregister_orphaned_ability(self)
		print("  🔥 [ONE-SHOT] Ability auto-removed after triggering")

func _check_trigger_conditions(cardData: CardData, event_card_data: CardData, game: Game, from_zone = null, to_zone = null) -> bool:
	"""Check if the trigger conditions for this ability are met"""
	var trigger_zones = trigger_conditions.get(TriggerCondition.TRIGGER_ZONES, [])
	if trigger_zones is Array and trigger_zones.size() > 0:
		var cardData_zone = game.game_data.get_card_zone(cardData)
		
		if cardData_zone not in trigger_zones:
			return false 
	
	# Check Origin condition for zone changes (e.g., "Origin$ Hand")
	var origin_filter = trigger_conditions.get(TriggerCondition.ORIGIN, "")
	if origin_filter != "" and from_zone != null:
		if not GameZone.matches_zone_filter(from_zone, origin_filter):
			return false
	
	# Check Destination condition for zone changes (e.g., "Destination$ Combat")
	var destination_filter = trigger_conditions.get(TriggerCondition.DESTINATION, "")
	if destination_filter != "" and to_zone != null:
		if not GameZone.matches_zone_filter(to_zone, destination_filter):
			# Debug logging for Elusive destination check
			var owner = get_owner()
			if owner and owner.cardName == "Grave Whisperer":
				print("🔍 [ELUSIVE] Destination filter '", destination_filter, "' did not match zone: ", GameZone.get_as_string(to_zone))
			return false
			
	var valid_card_filter = trigger_conditions.get(TriggerCondition.VALID_CARD, "")
	if valid_card_filter != "":
		# Special case: "Card.Self" means only this card can trigger this ability
		if valid_card_filter == "Card.Self":
			var matches = event_card_data == cardData
			if not matches:
				return false
		else:
			# Check if event card matches the filter (works with CardData directly)
			if not event_card_data:
				return false  # No card to validate against
			
			# Use unified filter from game (works in both headless and normal mode)
			var single_card: Array[CardData] = [event_card_data]
			if game._matches_card_filter(valid_card_filter).has(single_card):
				return false
	
	# Check "Condition" field (e.g., "Self.Attacked+ThisTurn")
	var condition_str = trigger_conditions.get(TriggerCondition.CONDITION, "")
	if condition_str != "":
		# Use AbilityManager to evaluate the condition
		var condition_met = AbilityManagerAL.evaluateCondition(condition_str, cardData)
		if not condition_met:
			return false
	
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
		GameEventType.CARD_DRAWN:
			return "CardDrawn"
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
		GameEventType.END_OF_TURN_CLEANUP:
			return "EndOfTurnCleanup"
		GameEventType.STRIKE:
			return "Strike"
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
		"CardDrawn":
			return GameEventType.CARD_DRAWN
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
		"EndOfTurnCleanup":
			return GameEventType.END_OF_TURN_CLEANUP
	return GameEventType.CARD_ENTERED_PLAY  # Default
