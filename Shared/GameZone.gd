extends Resource
class_name GameZone

enum e {
	HAND,
	PLAYER_BASE,
	COMBAT_ZONE,
	GRAVEYARD,
	DECK,
	EXTRA_DECK,
	UNKNOWN
}

# Helper to parse trigger zone strings to GameZone.e enum array
static func parse_trigger_zones(zone_str: String) -> Array:
	"""Convert trigger zone string to array of GameZone.e enum values"""
	var zones: Array = []
	var zone_parts = zone_str.split(",")
	
	for zone_part in zone_parts:
		zone_part = zone_part.strip_edges()
		match zone_part:
			"Battlefield":
				# Battlefield includes both base and combat zone
				zones.append(e.PLAYER_BASE)
				zones.append(e.COMBAT_ZONE)
			"Hand":
				zones.append(e.HAND)
			"Graveyard":
				zones.append(e.GRAVEYARD)
			"Deck":
				zones.append(e.DECK)
			"ExtraDeck":
				zones.append(e.EXTRA_DECK)
			_:
				push_warning("Unknown trigger zone: " + zone_part)
	
	return zones
