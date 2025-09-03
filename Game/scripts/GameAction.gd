extends RefCounted
class_name GameAction

enum TriggerType {
	CARD_PLAYED,
	CARD_MOVED,
	CARD_DRAWN
}

var trigger_type: TriggerType
var trigger_source: Card  # The card that caused the action
var from_zone: GameZone.e
var to_zone: GameZone.e
var additional_data: Dictionary = {}  # For any extra context needed

func _init(type: TriggerType, source: Card, from: GameZone.e = GameZone.e.HAND, to: GameZone.e = GameZone.e.HAND, data: Dictionary = {}):
	trigger_type = type
	trigger_source = source
	from_zone = from
	to_zone = to
	additional_data = data

func get_trigger_type_string() -> String:
	match trigger_type:
		TriggerType.CARD_PLAYED:
			return "CARD_PLAYED"
		TriggerType.CARD_MOVED:
			return "CHANGES_ZONE"
		TriggerType.CARD_DRAWN:
			return "CARD_DRAWN"
		_:
			return "UNKNOWN"

func is_zone_change() -> bool:
	return from_zone != to_zone

func is_battlefield_entry() -> bool:
	return to_zone == GameZone.e.PLAYER_BASE or to_zone == GameZone.e.COMBAT_ZONE

func is_battlefield_exit() -> bool:
	return from_zone == GameZone.e.PLAYER_BASE or from_zone == GameZone.e.COMBAT_ZONE
