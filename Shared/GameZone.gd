extends Resource
class_name GameZone

enum e {
	# Specific zones (MVC pattern with player/opponent distinction)
	HAND_PLAYER,
	HAND_OPPONENT,
	BATTLEFIELD_PLAYER,
	BATTLEFIELD_OPPONENT,
	COMBAT_PLAYER_1,
	COMBAT_PLAYER_2,
	COMBAT_PLAYER_3,
	COMBAT_OPPONENT_1,
	COMBAT_OPPONENT_2,
	COMBAT_OPPONENT_3,
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
		e.HAND_PLAYER: return "hand_player"
		e.HAND_OPPONENT: return "hand_opponent"
		e.BATTLEFIELD_PLAYER: return "battlefield_player"
		e.BATTLEFIELD_OPPONENT: return "battlefield_opponent"
		e.COMBAT_PLAYER_1: return "combat_player_1"
		e.COMBAT_PLAYER_2: return "combat_player_2"
		e.COMBAT_PLAYER_3: return "combat_player_3"
		e.COMBAT_OPPONENT_1: return "combat_opponent_1"
		e.COMBAT_OPPONENT_2: return "combat_opponent_2"
		e.COMBAT_OPPONENT_3: return "combat_opponent_3"
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
				# Battlefield includes both battlefield and combat zones for both players
				zones.append(e.BATTLEFIELD_PLAYER)
				zones.append(e.BATTLEFIELD_OPPONENT)
				zones.append(e.COMBAT_PLAYER_1)
				zones.append(e.COMBAT_PLAYER_2)
				zones.append(e.COMBAT_PLAYER_3)
				zones.append(e.COMBAT_OPPONENT_1)
				zones.append(e.COMBAT_OPPONENT_2)
				zones.append(e.COMBAT_OPPONENT_3)
			"Hand":
				zones.append(e.HAND_PLAYER)
				zones.append(e.HAND_OPPONENT)
			"Graveyard":
				zones.append(e.GRAVEYARD_PLAYER)
				zones.append(e.GRAVEYARD_OPPONENT)
			"Deck":
				zones.append(e.DECK_PLAYER)
				zones.append(e.DECK_OPPONENT)
			"ExtraDeck":
				zones.append(e.EXTRA_DECK_PLAYER)
			_:
				push_warning("Unknown trigger zone: " + zone_part)
	
	return zones

# Helper to check if a zone is a combat zone
static func is_combat_zone(zone: e) -> bool:
	return zone in [e.COMBAT_PLAYER_1, e.COMBAT_PLAYER_2, e.COMBAT_PLAYER_3,
					e.COMBAT_OPPONENT_1, e.COMBAT_OPPONENT_2, e.COMBAT_OPPONENT_3]

# Helper to check if a zone is a battlefield zone (non-combat)
static func is_battlefield_zone(zone: e) -> bool:
	return zone == e.BATTLEFIELD_PLAYER or zone == e.BATTLEFIELD_OPPONENT

# Helper to check if a zone is "in play" (battlefield or combat)
static func is_in_play(zone: e) -> bool:
	return is_battlefield_zone(zone) or is_combat_zone(zone)

# Helper to check if a zone belongs to the player
static func is_player_zone(zone: e) -> bool:
	return zone in [e.HAND_PLAYER, e.BATTLEFIELD_PLAYER, e.COMBAT_PLAYER_1, 
					e.COMBAT_PLAYER_2, e.COMBAT_PLAYER_3, e.GRAVEYARD_PLAYER, 
					e.DECK_PLAYER, e.EXTRA_DECK_PLAYER]

# Helper to check if a zone belongs to the opponent
static func is_opponent_zone(zone: e) -> bool:
	return zone in [e.HAND_OPPONENT, e.BATTLEFIELD_OPPONENT, e.COMBAT_OPPONENT_1,
					e.COMBAT_OPPONENT_2, e.COMBAT_OPPONENT_3, e.GRAVEYARD_OPPONENT,
					e.DECK_OPPONENT]
