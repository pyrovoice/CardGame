extends RefCounted
class_name GameAction

# Use the unified TriggerType enum
var trigger_type: int  # Will store TriggerType.Type values
var trigger_source: Card  # The card that caused the action
var from_zone: GameZone.e
var to_zone: GameZone.e
var additional_data: Dictionary = {}  # For any extra context needed

func _init(type: int, source: Card, from: GameZone.e = GameZone.e.HAND, to: GameZone.e = GameZone.e.HAND, data: Dictionary = {}):
	trigger_type = type
	trigger_source = source
	from_zone = from
	to_zone = to
	additional_data = data

func get_trigger_type_string() -> String:
	return TriggerType.type_to_string(trigger_type)

func is_zone_change() -> bool:
	return from_zone != to_zone

func is_battlefield_entry() -> bool:
	return to_zone == GameZone.e.PLAYER_BASE or to_zone == GameZone.e.COMBAT_ZONE

func is_battlefield_exit() -> bool:
	return from_zone == GameZone.e.PLAYER_BASE or from_zone == GameZone.e.COMBAT_ZONE
