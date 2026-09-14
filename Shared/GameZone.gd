extends Resource
class_name GameZone

enum e {
	# Specific zones (MVC pattern with player/opponent distinction)
	HAND_PLAYER,
	HAND_AGGRO,
	HAND_CONTROL,
	HAND_COMBO,
	HAND_COMMANDER,
	BATTLEFIELD_PLAYER,
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
	DECK_AGGRO,
	DECK_CONTROL,
	DECK_COMBO,
	DECK_COMMANDER,
	EXTRA_DECK_PLAYER,
	RECYCLE_ZONE,
	EXILE_PLAYER,
	EXILE_OPPONENT,
	
	UNKNOWN
}

# Helper to convert GameZone.e to string for display/debug
static func get_as_string(zone: e) -> String:
	match zone:
		e.HAND_PLAYER: return "hand_player"
		e.HAND_AGGRO: return "hand_aggro"
		e.HAND_CONTROL: return "hand_control"
		e.HAND_COMBO: return "hand_combo"
		e.HAND_COMMANDER: return "hand_commander"
		e.BATTLEFIELD_PLAYER: return "battlefield_player"
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
		e.DECK_AGGRO: return "deck_aggro"
		e.DECK_CONTROL: return "deck_control"
		e.DECK_COMBO: return "deck_combo"
		e.DECK_COMMANDER: return "deck_commander"
		e.EXTRA_DECK_PLAYER: return "extra_deck_player"
		e.RECYCLE_ZONE: return "recycle_zone"
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
				zones.append(e.COMBAT_PLAYER_1)
				zones.append(e.COMBAT_PLAYER_2)
				zones.append(e.COMBAT_PLAYER_3)
				zones.append(e.COMBAT_OPPONENT_1)
				zones.append(e.COMBAT_OPPONENT_2)
				zones.append(e.COMBAT_OPPONENT_3)
			"Hand":
				zones.append(e.HAND_PLAYER)
				zones.append(e.HAND_AGGRO)
				zones.append(e.HAND_CONTROL)
				zones.append(e.HAND_COMBO)
				zones.append(e.HAND_COMMANDER)
			"Graveyard":
				zones.append(e.GRAVEYARD_PLAYER)
				zones.append(e.GRAVEYARD_OPPONENT)
			"Deck":
				zones.append(e.DECK_PLAYER)
				zones.append(e.DECK_OPPONENT)
				zones.append(e.DECK_AGGRO)
				zones.append(e.DECK_CONTROL)
				zones.append(e.DECK_COMBO)
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
	# Only the player has a battlefield staging area - opponent cards go straight to combat
	return zone == e.BATTLEFIELD_PLAYER

# Helper to check if a zone is "in play" (battlefield or combat)
static func is_in_play(zone: e) -> bool:
	return is_battlefield_zone(zone) or is_combat_zone(zone)

# Helper to check if a zone is a hand zone (player or any opponent Lieutenant/Commander)
static func is_hand_zone(zone: e) -> bool:
	return zone in [e.HAND_PLAYER, e.HAND_AGGRO, e.HAND_CONTROL, e.HAND_COMBO, e.HAND_COMMANDER]

# Helper to check if a zone belongs to the player
static func is_player_zone(zone: e) -> bool:
	return zone in [e.HAND_PLAYER, e.BATTLEFIELD_PLAYER, e.COMBAT_PLAYER_1, 
					e.COMBAT_PLAYER_2, e.COMBAT_PLAYER_3, e.GRAVEYARD_PLAYER, 
					e.DECK_PLAYER, e.EXTRA_DECK_PLAYER]

# Helper to check if a zone belongs to the opponent
static func is_opponent_zone(zone: e) -> bool:
	return zone in [e.HAND_AGGRO, e.HAND_CONTROL, e.HAND_COMBO, e.HAND_COMMANDER, e.COMBAT_OPPONENT_1,
					e.COMBAT_OPPONENT_2, e.COMBAT_OPPONENT_3, e.GRAVEYARD_OPPONENT,
					e.DECK_OPPONENT, e.DECK_AGGRO, e.DECK_CONTROL, e.DECK_COMBO, e.DECK_COMMANDER]

# Helper to check if a zone matches a zone string filter (for trigger conditions)
static func matches_zone_filter(zone: e, filter: String) -> bool:
	"""Check if a zone matches a text filter like 'Combat', 'Hand', 'Battlefield', etc."""
	filter = filter.strip_edges()
	
	match filter:
		"Combat":
			return is_combat_zone(zone)
		"Battlefield":
			return is_battlefield_zone(zone) or is_combat_zone(zone)
		"Hand":
			return is_hand_zone(zone)
		"Graveyard":
			return zone in [e.GRAVEYARD_PLAYER, e.GRAVEYARD_OPPONENT]
		"Deck":
			return zone in [e.DECK_PLAYER, e.DECK_OPPONENT, e.DECK_AGGRO, e.DECK_CONTROL, e.DECK_COMBO]
		"ExtraDeck":
			return zone == e.EXTRA_DECK_PLAYER
		_:
			push_warning("Unknown zone filter: " + filter)
			return false
