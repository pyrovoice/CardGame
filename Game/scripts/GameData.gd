extends RefCounted
class_name GameData

## GameData - Single Source of Truth for All Game State
## 
## This class maintains all game state as pure data:
## - Player stats (life, gold, etc.) using SignalInt for UI reactivity
## - Card locations and positions (CardData instances)
## - Combat zone tracking
## - Can be serialized/deserialized for save/load and undo

# Player stats using SignalInt
var player_life: SignalInt
var player_shield: SignalInt
var player_points: SignalInt
var player_gold: SignalInt
var opponent_gold: SignalInt
var recycling_remaining: SignalInt
var combatLocationDatas: Array[CombatLocationData] = []
# Game state using SignalInt
var danger_level: SignalInt
var current_turn: SignalInt

# Deck configurations
var playerDeckList: DeckList
var opponentDeckList: DeckList

# === CARD TRACKING (Data Model) ===
# Unified zone tracking - all zones use the same pattern (PRIVATE: use get_cards_in_zone())
var _cards_by_zone: Dictionary = {}  # GameZone.e -> Array[CardData]

func _init():
	# Initialize SignalInt values
	player_life = SignalInt.new(3)
	player_shield = SignalInt.new(3)
	player_points = SignalInt.new(0)
	player_gold = SignalInt.new(3)  # Starting gold
	opponent_gold = SignalInt.new(0)
	recycling_remaining = SignalInt.new(3)  # Recycling uses per turn
	danger_level = SignalInt.new(5)
	current_turn = SignalInt.new(1)
	
	# Initialize empty deck lists (will be populated in game.gd)
	playerDeckList = DeckList.new([])
	opponentDeckList = DeckList.new([])
	
	# Initialize all zone arrays
	for zone in GameZone.e.values():
		if zone != GameZone.e.UNKNOWN:
			var zone_cards: Array[CardData] = []
			_cards_by_zone[zone] = zone_cards

func increase_danger_level():
	"""Increase the danger level by 1 each turn"""
	danger_level.value += 1

func damage_player(amount: float):
	"""Apply damage to the player, shield absorbs damage first"""
	var remaining_damage = amount
	
	# Shield absorbs damage first
	if player_shield.value > 0:
		var shield_damage = min(player_shield.value, remaining_damage)
		player_shield.value -= shield_damage
		remaining_damage -= shield_damage
	
	# Remaining damage goes to life
	if remaining_damage > 0:
		player_life.value -= remaining_damage

func add_player_points(amount: int):
	"""Add points to the player's score"""
	player_points.value += amount

func add_gold(amount: int):
	"""Add gold to the player's resources"""
	player_gold.value += amount

func spend_gold(amount: int, playerOwned) -> bool:
	"""Spend gold if player has enough, returns true if successful"""
	var gold = player_gold if playerOwned else opponent_gold
	if gold.getValue() >= amount:
		gold.setValue(gold.getValue() - amount)
		return true
	return false

func has_gold(amount: int, playerOwned) -> bool:
	"""Check if player has enough gold"""
	return player_gold.getValue() >= amount if playerOwned else opponent_gold.getValue() >= amount

func start_new_turn():
	"""Start a new turn and increase danger level"""
	current_turn.value += 1
	increase_danger_level()
	# Reset recycling uses
	recycling_remaining.value = 3

func is_player_defeated() -> bool:
	"""Check if the player has been defeated"""
	return player_life.value <= 0

func get_game_state() -> Dictionary:
	"""Get the current game state as a dictionary"""
	return {
		"player_life": player_life.value,
		"player_shield": player_shield.value,
		"player_points": player_points.value,
		"player_gold": player_gold.value,
		"danger_level": danger_level.value,
		"current_turn": current_turn.value
	}

func reset_game():
	"""Reset the game to initial state"""
	player_life.value = 3
	player_shield.value = 3
	player_points.value = 0
	player_gold.value = 3
	danger_level.value = 5
	current_turn.value = 1
	
	# Reset capture values
	for c in combatLocationDatas:
		c.player_capture_current.setValue(0)
		c.opponent_capture_current.setValue(0)
		c.player_capture_threshold.setValue(10)
		c.opponent_capture_threshold.setValue(10)
	reset_combat_resolution_flags()

func reset_combat_resolution_flags():
	"""Reset all combat resolution flags at start of turn"""
	for c in combatLocationDatas:
		c.isCombatResolved.setValue(false)

func setOpponentGold():
	opponent_gold.setValue(danger_level.getValue())

func debug_player_resources():
	"""Debug function to print current player resources"""
	print("=== PLAYER RESOURCES ===")
	print("Life: ", player_life.value)
	print("Shield: ", player_shield.value)
	print("Gold: ", player_gold.value)
	print("Points: ", player_points.value)
	print("Turn: ", current_turn.value)
	print("Danger Level: ", danger_level.value)
	print("========================")

func is_combat_resolved(combat_zone: CombatZone):
	return get_combat_zone_data(combat_zone).isCombatResolved.value

func set_combat_resolved(combat_zone, b):
	get_combat_zone_data(combat_zone).isCombatResolved.value = b
	
func get_combat_zone_data(combat_zone) -> CombatLocationData:
	var finds = combatLocationDatas.filter(func(c:CombatLocationData): return c.relatedLocation == combat_zone)
	if finds.size()==0:
		return
	return finds[0]

func add_location_capture_value(damage: int, is_player_damage: bool, combatZone: CombatZone):
	var data: CombatLocationData = get_combat_zone_data(combatZone)
	var capture = data.player_capture_current if is_player_damage else data.opponent_capture_current
	capture.setValue(capture.getValue() + damage)

func reset_combat_zone_data(combat_zone):
	var data = get_combat_zone_data(combat_zone)
	data.opponent_capture_current.setValue(0)
	data.player_capture_current.setValue(0)

# === CARD DATA MODEL METHODS ===

## Get all cards currently in play (battlefield + combat)
func get_cards_in_play() -> Array[CardData]:
	var result: Array[CardData] = []
	
	# Add battlefield cards
	result.append_array(get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER))
	result.append_array(get_cards_in_zone(GameZone.e.BATTLEFIELD_OPPONENT))
	
	# Add combat zone cards
	for zone in [GameZone.e.COMBAT_PLAYER_1, GameZone.e.COMBAT_PLAYER_2, GameZone.e.COMBAT_PLAYER_3,
				 GameZone.e.COMBAT_OPPONENT_1, GameZone.e.COMBAT_OPPONENT_2, GameZone.e.COMBAT_OPPONENT_3]:
		result.append_array(get_cards_in_zone(zone))
	
	return result

## Get cards controlled by player
func get_player_controlled_cards() -> Array[CardData]:
	return get_cards_in_play().filter(func(c): return c.playerControlled)

## Get cards controlled by opponent
func get_opponent_controlled_cards() -> Array[CardData]:
	return get_cards_in_play().filter(func(c): return not c.playerControlled)

## Get cards owned by player (regardless of control)
func get_player_owned_cards() -> Array[CardData]:
	return get_cards_in_play().filter(func(c): return c.playerOwned)

## Get cards owned by opponent (regardless of control)
func get_opponent_owned_cards() -> Array[CardData]:
	return get_cards_in_play().filter(func(c): return not c.playerOwned)

## Add a card to a specific zone
func add_card_to_zone(card_data: CardData, zone: GameZone.e, index: int = -1) -> int:
	if not card_data:
		push_error("GameData.add_card_to_zone: card_data is null")
		return -1
	
	# Remove from previous zone if exists
	if card_data.current_zone != GameZone.e.UNKNOWN:
		var removalSuccess = remove_card_from_zone(card_data)
		if !removalSuccess:
			return -1
	
	# Add to zone array
	if zone == GameZone.e.UNKNOWN:
		push_error("GameData.add_card_to_zone: Cannot add to UNKNOWN zone")
		return -1
	
	# Insert at specified index or append to end
	card_data.current_zone = zone
	if index >= 0 and index < _cards_by_zone[zone].size():
		_cards_by_zone[zone].insert(index, card_data)
		return index
	else:
		_cards_by_zone[zone].append(card_data)
		return _cards_by_zone[zone].size()

## Remove a card from its current zone
func remove_card_from_zone(card_data: CardData) -> bool:
	if not card_data:
		return false
	
	var zone: GameZone.e = card_data.current_zone
	if zone == GameZone.e.UNKNOWN:
		return false
	
	# Remove from zone array
	if _cards_by_zone.has(zone):
		_cards_by_zone[zone].erase(card_data)
	
	# Clear card's zone tracking
	card_data.current_zone = GameZone.e.UNKNOWN
	return true

## Move a card from one zone to another
func move_card(card_data: CardData, to_zone: GameZone.e, index: int = -1) -> int:
	if remove_card_from_zone(card_data):
		return add_card_to_zone(card_data, to_zone, index)
	return -1

## Completely destroy a card - remove from all tracking
func destroy_card(card_data: CardData) -> bool:
	"""Remove a card entirely from the game (for recycling, exile, etc.)
	
	Args:
		card_data: The card to destroy
	
	Returns:
		bool: True if card was successfully destroyed
	"""
	if not card_data:
		return false
	
	# Remove from current zone
	var success = remove_card_from_zone(card_data)
	if not success:
		push_warning("destroy_card: Failed to remove card from zone: ", card_data.cardName)
		return false
	
	# Card is now removed from all zone tracking
	card_data.current_zone = GameZone.e.UNKNOWN
	return true

## Get the zone a card is currently in (with verification)
func get_card_zone(card_data: CardData) -> GameZone.e:
	if not card_data:
		return GameZone.e.UNKNOWN
	
	var claimed_zone = card_data.current_zone
	
	# Verify card is actually in the claimed zone
	if claimed_zone != GameZone.e.UNKNOWN:
		if _cards_by_zone.has(claimed_zone) and _cards_by_zone[claimed_zone].has(card_data):
			return claimed_zone
		
		# Card claims a zone but isn't actually there - data corruption!
		push_warning("GameData.get_card_zone: Card '%s' claims zone %s but isn't in that zone array. Searching all zones..." % [card_data.cardName, GameZone.get_as_string(claimed_zone)])
	
	# Card doesn't know its zone or verification failed - search all zones
	var actual_zone = _find_card_in_zones(card_data)
	if actual_zone != GameZone.e.UNKNOWN:
		push_warning("GameData.get_card_zone: Card '%s' found in zone %s. Updating card's zone tracking." % [card_data.cardName, GameZone.get_as_string(actual_zone)])
		card_data.current_zone = actual_zone
		return actual_zone
	
	return GameZone.e.UNKNOWN

## Search all zones to find a card (slow - only called when verification fails)
func _find_card_in_zones(card_data: CardData) -> GameZone.e:
	for zone in _cards_by_zone:
		if _cards_by_zone[zone].has(card_data):
			return zone
	return GameZone.e.UNKNOWN

## Get array index of card in its combat zone (returns -1 if not in combat)
func get_card_combat_index(card_data: CardData) -> int:
	var zone = get_card_zone(card_data)
	if not GameZone.is_combat_zone(zone):
		return -1
	return get_cards_in_zone(zone).find(card_data)

## Get cards in a specific zone
func get_cards_in_zone(zone: GameZone.e) -> Array[CardData]:
	if not _cards_by_zone.has(zone):
		return []
	return (_cards_by_zone[zone] as Array[CardData])

## Parse zone string to GameZone.e enum
func parse_zone_string_to_enum(zone_str: String, from_player_perspective: bool) -> GameZone.e:
	"""Parse zone string to GameZone.e enum
	
	Args:
		zone_str: Zone string like "Graveyard.Opponent", "Deck.Player", "Hand.Controller"
		from_player_perspective: If true, "Opponent" = opponent zones. If false (opponent card), "Opponent" = player zones.
	
	Returns:
		GameZone.e enum
	"""
	# Handle .Controller - convert based on perspective
	var resolved_zone = zone_str
	if ".Controller" in zone_str:
		if from_player_perspective:
			resolved_zone = zone_str.replace(".Controller", ".Player")
		else:
			resolved_zone = zone_str.replace(".Controller", ".Opponent")
	# For opponent-controlled cards, swap Player/Opponent perspective
	elif not from_player_perspective:
		if ".Player" in zone_str:
			resolved_zone = zone_str.replace(".Player", ".Opponent")
		elif ".Opponent" in zone_str:
			resolved_zone = zone_str.replace(".Opponent", ".Player")
	
	# Map to GameZone.e enum
	match resolved_zone:
		"Graveyard.Player":
			return GameZone.e.GRAVEYARD_PLAYER
		"Graveyard.Opponent":
			return GameZone.e.GRAVEYARD_OPPONENT
		"Deck.Player":
			return GameZone.e.DECK_PLAYER
		"Deck.Opponent":
			return GameZone.e.DECK_OPPONENT
		"Hand.Player":
			return GameZone.e.HAND_PLAYER
		"Hand.Opponent":
			return GameZone.e.HAND_OPPONENT
		"ExtraDeck.Player":
			return GameZone.e.EXTRA_DECK_PLAYER
		"Battlefield.Player", "PlayerBase":
			return GameZone.e.BATTLEFIELD_PLAYER
		"Battlefield.Opponent":
			return GameZone.e.BATTLEFIELD_OPPONENT
		_:
			push_error("Unknown zone string: ", zone_str, " (resolved to: ", resolved_zone, ")")
			return GameZone.e.UNKNOWN

## Serialize complete game state to dictionary (for save/load/undo)
func serialize() -> Dictionary:
	var data = {
		"version": 1,
		"player_stats": {
			"life": player_life.value,
			"shield": player_shield.value,
			"points": player_points.value,
			"gold": player_gold.value,
			"opponent_gold": opponent_gold.value,
			"danger_level": danger_level.value,
			"current_turn": current_turn.value
		},
		"zones": {},
		"positions": {},
		"combat_spots": {}
	}
	
	# Serialize each zone (use GameZone.get_as_string() for keys)
	for zone in _cards_by_zone:
		data["zones"][GameZone.get_as_string(zone)] = _serialize_card_array(_cards_by_zone[zone])
	
	return data

func _serialize_card_array(cards: Array[CardData]) -> Array:
	var result = []
	for card in cards:
		result.append(card.get_instance_id())
	return result

## Create a deep copy for undo system
func duplicate_state() -> GameData:
	var copy = GameData.new()
	
	# Copy player stats (SignalInt values)
	copy.player_life.value = player_life.value
	copy.player_shield.value = player_shield.value
	copy.player_points.value = player_points.value
	copy.player_gold.value = player_gold.value
	copy.opponent_gold.value = opponent_gold.value
	copy.danger_level.value = danger_level.value
	copy.current_turn.value = current_turn.value
	
	# Deep copy all zone arrays
	for zone in _cards_by_zone:
		copy._cards_by_zone[zone] = _cards_by_zone[zone].duplicate()
	
	return copy

## Debug: Print current state
func print_game_state() -> void:
	print("=== Complete Game State ===")
	print("Life: ", player_life.value, " | Shield: ", player_shield.value, " | Gold: ", player_gold.value)
	print("Turn: ", current_turn.value, " | Danger: ", danger_level.value)
	print("")
	print("Player Hand: ", get_cards_in_zone(GameZone.e.HAND_PLAYER).size(), " cards")
	print("Opponent Hand: ", get_cards_in_zone(GameZone.e.HAND_OPPONENT).size(), " cards")
	print("Player Battlefield: ", get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size(), " cards")
	print("Opponent Battlefield: ", get_cards_in_zone(GameZone.e.BATTLEFIELD_OPPONENT).size(), " cards")
	print("Player Graveyard: ", get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size(), " cards")
	print("Opponent Graveyard: ", get_cards_in_zone(GameZone.e.GRAVEYARD_OPPONENT).size(), " cards")
	print("Total Zones: ", _cards_by_zone.size())
	print("===========================")
