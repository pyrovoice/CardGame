extends Resource
class_name GameZone

enum e {
	# Generic zones (for getCardZone - backwards compatibility with UI/gameplay logic)
	HAND,
	PLAYER_BASE,
	COMBAT_ZONE,
	GRAVEYARD,
	DECK,
	EXTRA_DECK,
	
	# Specific zones (for GameData - MVC pattern with player/opponent distinction)
	HAND_PLAYER,
	HAND_OPPONENT,
	BATTLEFIELD_PLAYER,
	BATTLEFIELD_OPPONENT,
	COMBAT_PLAYER,
	COMBAT_OPPONENT,
	GRAVEYARD_PLAYER,
	GRAVEYARD_OPPONENT,
	DECK_PLAYER,
	DECK_OPPONENT,
	EXTRA_DECK_PLAYER,
	
	UNKNOWN
}

# Helper to convert GameZone.e to string for display/debug
static func get_as_string(zone: e) -> String:
	match zone:
		e.HAND: return "hand"
		e.PLAYER_BASE: return "player_base"
		e.COMBAT_ZONE: return "combat_zone"
		e.GRAVEYARD: return "graveyard"
		e.DECK: return "deck"
		e.EXTRA_DECK: return "extra_deck"
		e.HAND_PLAYER: return "hand_player"
		e.HAND_OPPONENT: return "hand_opponent"
		e.BATTLEFIELD_PLAYER: return "battlefield_player"
		e.BATTLEFIELD_OPPONENT: return "battlefield_opponent"
		e.COMBAT_PLAYER: return "combat_player"
		e.COMBAT_OPPONENT: return "combat_opponent"
		e.GRAVEYARD_PLAYER: return "graveyard_player"
		e.GRAVEYARD_OPPONENT: return "graveyard_opponent"
		e.DECK_PLAYER: return "deck_player"
		e.DECK_OPPONENT: return "deck_opponent"
		e.EXTRA_DECK_PLAYER: return "extra_deck_player"
		_: return "unknown"

# Helper to parse trigger zone strings to GameZone.e enum array
static func parse_trigger_zones(zone_str: String) -> Array:
	"""Convert trigger zone string to array of GameZone.e enum values"""
	var zones: Array = []
	var zone_parts = zone_str.split(",")
	
	for zone_part in zone_parts:
		zone_part = zone_part.strip_edges()
		match zone_part:
			"Battlefield":
				# Battlefield includes both base and combat zone (generic version)
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
