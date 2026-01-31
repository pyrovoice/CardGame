extends RefCounted
class_name TriggerType

# Unified enum for all trigger types in the game
enum Type {
	CARD_DRAWN,
	CARD_PLAYED,  # Card played from hand
	CARD_ENTERS,  # Card entering the battlefield (played from hand or created by effects)
	CARD_ATTACKS,  # Card moving from PlayerBase to CombatLocation
	CHANGED_ZONE,  # Card changing zones (with Origin/Destination filtering)
	PHASE,  # Phase-based triggers (beginning of turn, combat, end of turn)
	STRIKE  # Creature strikes in combat
}

# Convert trigger type enum to string representation
static func type_to_string(trigger_type: Type) -> String:
	match trigger_type:
		Type.CARD_DRAWN:
			return "CardDraw"
		Type.CARD_PLAYED:
			return "CardPlayed"
		Type.CARD_ENTERS:
			return "CardEnters"
		Type.CARD_ATTACKS:
			return "StartAttack"
		Type.CHANGED_ZONE:
			return "ChangedZone"
		Type.PHASE:
			return "Phase"
		Type.STRIKE:
			return "Strikes"
		_:
			return "UNKNOWN"

# Convert string representation to trigger type enum
static func string_to_type(trigger_string: String) -> Type:
	match trigger_string:
		"CardDraw":
			return Type.CARD_DRAWN
		"CardPlayed":
			return Type.CARD_PLAYED
		"CardEnters":
			return Type.CARD_ENTERS
		"StartAttack":
			return Type.CARD_ATTACKS
		"ChangedZone":
			return Type.CHANGED_ZONE
		"Phase":
			return Type.PHASE
		"Strikes":
			return Type.STRIKE
		# Support old format for backwards compatibility
		"ChangesZone":
			return Type.CHANGED_ZONE  # Legacy mapping
		"CARD_DRAWN":
			return Type.CARD_DRAWN
		"CARD_PLAYED":
			return Type.CARD_PLAYED
		"CARD_ENTERS":
			return Type.CARD_ENTERS
		"CARD_ATTACKS":
			return Type.CARD_ATTACKS
		_:
			push_warning("Unknown trigger type string: " + trigger_string)
			return Type.CARD_PLAYED  # Default fallback

# Get all available trigger type strings (in card file format)
static func get_all_strings() -> Array[String]:
	return ["CardDraw", "CardPlayed", "CardEnters", "StartAttack", "ChangedZone", "Phase"]

# Check if a trigger type represents a card entering the battlefield
static func is_battlefield_entry(trigger_type: Type) -> bool:
	return trigger_type == Type.CARD_ENTERS

# Check if a trigger type represents a card being played from hand
static func is_card_played(trigger_type: Type) -> bool:
	return trigger_type == Type.CARD_PLAYED

# Check if a trigger type represents a card attacking
static func is_card_attacks(trigger_type: Type) -> bool:
	return trigger_type == Type.CARD_ATTACKS

# Check if a trigger type represents a card being drawn
static func is_card_drawn(trigger_type: Type) -> bool:
	return trigger_type == Type.CARD_DRAWN

# Check if a trigger type represents a phase trigger
static func is_phase_trigger(trigger_type: Type) -> bool:
	return trigger_type == Type.PHASE
