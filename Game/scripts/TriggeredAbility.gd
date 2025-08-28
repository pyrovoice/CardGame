extends RefCounted
class_name TriggeredAbility

# Triggered abilities that respond to game events

enum TriggerType {
	CHANGES_ZONE,
	CARD_PLAYED,
	# Add more trigger types as needed
}

var description: String = ""
var trigger_type: TriggerType
var trigger_conditions: Dictionary = {}
var effect_name: String = ""
var effect_parameters: Dictionary = {}

func _init(
	_trigger_type: TriggerType,
	_trigger_conditions: Dictionary = {},
	_effect_name: String = "",
	_effect_parameters: Dictionary = {},
	_description: String = ""
):
	description = _description
	trigger_type = _trigger_type
	trigger_conditions = _trigger_conditions.duplicate()
	effect_name = _effect_name
	effect_parameters = _effect_parameters.duplicate()

func execute(card: Card, _game_context: Node):
	# Execute the triggered ability based on effect name
	match effect_name:
		"TrigToken", "TrigCreateGoblin":
			execute_token_creation(card, _game_context)
		_:
			push_error("Unknown effect: " + effect_name)

func execute_token_creation(card: Card, _game_context: Node):
	# Create token based on parameters
	if "TokenScript" in effect_parameters:
		var token_script = effect_parameters["TokenScript"]
		print("Creating token: ", token_script, " for card: ", card.cardData.cardName)
		# TODO: Implement actual token creation logic
		# This would load the token from Cards/Tokens/ and create it at the same location

func can_trigger(_event_type: String, event_data: Dictionary) -> bool:
	# Check if this ability should trigger based on the event
	match trigger_type:
		TriggerType.CHANGES_ZONE:
			return check_zone_change_trigger(event_data)
		TriggerType.CARD_PLAYED:
			return check_card_played_trigger(event_data)
		_:
			return false

func check_zone_change_trigger(event_data: Dictionary) -> bool:
	# Check if zone change conditions are met
	var origin = trigger_conditions.get("Origin", "Any")
	var destination = trigger_conditions.get("Destination", "Any")
	var valid_card = trigger_conditions.get("ValidCard", "Any")
	
	# Basic validation - can be expanded
	if origin != "Any" and event_data.get("origin", "") != origin:
		return false
	if destination != "Any" and event_data.get("destination", "") != destination:
		return false
	if valid_card == "Card.Self" and event_data.get("card") != self:
		return false
	
	return true

func check_card_played_trigger(event_data: Dictionary) -> bool:
	# Check if card played conditions are met
	var valid_card = trigger_conditions.get("ValidCard", "Any")
	var valid_player = trigger_conditions.get("ValidActivatingPlayer", "Any")
	var trigger_zones = trigger_conditions.get("TriggerZones", "Any")
	
	# Check if the played card matches the valid card condition
	var played_card = event_data.get("card")
	if valid_card != "Any" and played_card:
		# Check if the card has the required subtype
		var card_data = played_card.get("cardData")
		if card_data and not valid_card in card_data.subtypes:
			return false
	
	# Check if the player matches
	if valid_player == "You" and not event_data.get("is_owner_player", false):
		return false
	
	# Check if trigger is in the right zone (assuming the triggering card is on battlefield)
	if trigger_zones != "Any" and trigger_zones != "Battlefield":
		return false
	
	return true

func describe() -> String:
	var trigger_name = ""
	match trigger_type:
		TriggerType.CHANGES_ZONE:
			trigger_name = "Zone Change"
		TriggerType.CARD_PLAYED:
			trigger_name = "Card Played"
	
	return "Triggered Ability (%s): %s -> %s" % [trigger_name, description, effect_name]
