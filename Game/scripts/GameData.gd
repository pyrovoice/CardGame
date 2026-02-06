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
var combatLocationDatas: Array[CombatLocationData] = []
# Game state using SignalInt
var danger_level: SignalInt
var current_turn: SignalInt

# Deck configurations
var playerDeckList: DeckList
var opponentDeckList: DeckList

# === CARD TRACKING (Data Model) ===
# Zone tracking - arrays of CardData instances
var cards_in_hand_player: Array[CardData] = []
var cards_in_hand_opponent: Array[CardData] = []
var cards_in_extra_hand_player: Array[CardData] = []
var cards_on_battlefield_player: Array[CardData] = []
var cards_on_battlefield_opponent: Array[CardData] = []
var cards_in_graveyard_player: Array[CardData] = []
var cards_in_graveyard_opponent: Array[CardData] = []
var cards_in_deck_player: Array[CardData] = []
var cards_in_deck_opponent: Array[CardData] = []
var cards_in_extra_deck_player: Array[CardData] = []

# Combat zone tracking - maps zone to arrays of CardData
var cards_in_combat_zones: Dictionary = {}  # CombatZone -> Array[CardData]

# Card world positions (for view synchronization and animations)
var card_positions: Dictionary = {}  # CardData -> Vector3

# Card to zone mapping (for quick lookups)
var card_to_zone: Dictionary = {}  # CardData -> GameZone.e

# Combat spot assignments (for combat resolution)
var card_to_combat_spot: Dictionary = {}  # CardData -> CombatantFightingSpot

# Note: Zone tracking now uses GameZone.e enum for type safety
# Combat zones still use string-based tracking in cards_in_combat_zones since they're dynamic

func _init():
	# Initialize SignalInt values
	player_life = SignalInt.new(3)
	player_shield = SignalInt.new(3)
	player_points = SignalInt.new(0)
	player_gold = SignalInt.new(3)  # Starting gold
	opponent_gold = SignalInt.new(0)
	danger_level = SignalInt.new(5)
	current_turn = SignalInt.new(1)
	
	# Initialize empty deck lists (will be populated in game.gd)
	playerDeckList = DeckList.new([])
	opponentDeckList = DeckList.new([])

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
	# Add gold per turn (could be made configurable)
	add_gold(1)

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
	result.append_array(cards_on_battlefield_player)
	result.append_array(cards_on_battlefield_opponent)
	
	# Add cards from all combat zones
	for zone_cards in cards_in_combat_zones.values():
		result.append_array(zone_cards)
	
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
func add_card_to_zone(card_data: CardData, zone: GameZone.e, position: Vector3 = Vector3.ZERO) -> void:
	if not card_data:
		push_error("GameData.add_card_to_zone: card_data is null")
		return
	
	# Remove from previous zone if exists
	if card_to_zone.has(card_data):
		remove_card_from_zone(card_data)
	
	# Add to new zone
	match zone:
		GameZone.e.HAND_PLAYER:
			cards_in_hand_player.append(card_data)
		GameZone.e.HAND_OPPONENT:
			cards_in_hand_opponent.append(card_data)
		GameZone.e.BATTLEFIELD_PLAYER:
			cards_on_battlefield_player.append(card_data)
		GameZone.e.BATTLEFIELD_OPPONENT:
			cards_on_battlefield_opponent.append(card_data)
		GameZone.e.GRAVEYARD_PLAYER:
			cards_in_graveyard_player.append(card_data)
		GameZone.e.GRAVEYARD_OPPONENT:
			cards_in_graveyard_opponent.append(card_data)
		GameZone.e.DECK_PLAYER:
			cards_in_deck_player.append(card_data)
		GameZone.e.DECK_OPPONENT:
			cards_in_deck_opponent.append(card_data)
		GameZone.e.EXTRA_DECK_PLAYER:
			cards_in_extra_deck_player.append(card_data)
		GameZone.e.COMBAT_PLAYER, GameZone.e.COMBAT_OPPONENT:
			# Combat zones tracked separately - use card_to_combat_spot for specific location
			pass
		_:
			push_error("GameData.add_card_to_zone: Unknown zone: " + str(zone))
			return
	
	# Update tracking
	card_to_zone[card_data] = zone
	card_positions[card_data] = position

## Remove a card from its current zone
func remove_card_from_zone(card_data: CardData) -> void:
	if not card_data:
		return
	
	if not card_to_zone.has(card_data):
		return
	
	var zone: GameZone.e = card_to_zone[card_data]
	
	match zone:
		GameZone.e.HAND_PLAYER:
			cards_in_hand_player.erase(card_data)
		GameZone.e.HAND_OPPONENT:
			cards_in_hand_opponent.erase(card_data)
		GameZone.e.BATTLEFIELD_PLAYER:
			cards_on_battlefield_player.erase(card_data)
		GameZone.e.BATTLEFIELD_OPPONENT:
			cards_on_battlefield_opponent.erase(card_data)
		GameZone.e.GRAVEYARD_PLAYER:
			cards_in_graveyard_player.erase(card_data)
		GameZone.e.GRAVEYARD_OPPONENT:
			cards_in_graveyard_opponent.erase(card_data)
		GameZone.e.DECK_PLAYER:
			cards_in_deck_player.erase(card_data)
		GameZone.e.DECK_OPPONENT:
			cards_in_deck_opponent.erase(card_data)
		GameZone.e.EXTRA_DECK_PLAYER:
			cards_in_extra_deck_player.erase(card_data)
		GameZone.e.COMBAT_PLAYER, GameZone.e.COMBAT_OPPONENT:
			# Combat zones - handled via card_to_combat_spot
			pass
	
	card_to_zone.erase(card_data)
	card_positions.erase(card_data)
	card_to_combat_spot.erase(card_data)

## Move a card from one zone to another
func move_card(card_data: CardData, to_zone: GameZone.e, position: Vector3 = Vector3.ZERO) -> void:
	remove_card_from_zone(card_data)
	add_card_to_zone(card_data, to_zone, position)

## Get the zone a card is currently in
func get_card_zone(card_data: CardData) -> String:
	return card_to_zone.get(card_data, "")

## Get card position
func get_card_position(card_data: CardData) -> Vector3:
	return card_positions.get(card_data, Vector3.ZERO)

## Update card position (for view synchronization)
func set_card_position(card_data: CardData, position: Vector3) -> void:
	card_positions[card_data] = position

## Assign card to combat spot
func assign_card_to_combat_spot(card_data: CardData, spot: CombatantFightingSpot) -> void:
	card_to_combat_spot[card_data] = spot

## Get combat spot for card
func get_card_combat_spot(card_data: CardData) -> CombatantFightingSpot:
	return card_to_combat_spot.get(card_data, null)

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
	data["zones"][GameZone.get_as_string(GameZone.e.HAND_PLAYER)] = _serialize_card_array(cards_in_hand_player)
	data["zones"][GameZone.get_as_string(GameZone.e.HAND_OPPONENT)] = _serialize_card_array(cards_in_hand_opponent)
	data["zones"][GameZone.get_as_string(GameZone.e.BATTLEFIELD_PLAYER)] = _serialize_card_array(cards_on_battlefield_player)
	data["zones"][GameZone.get_as_string(GameZone.e.BATTLEFIELD_OPPONENT)] = _serialize_card_array(cards_on_battlefield_opponent)
	data["zones"][GameZone.get_as_string(GameZone.e.GRAVEYARD_PLAYER)] = _serialize_card_array(cards_in_graveyard_player)
	data["zones"][GameZone.get_as_string(GameZone.e.GRAVEYARD_OPPONENT)] = _serialize_card_array(cards_in_graveyard_opponent)
	data["zones"][GameZone.get_as_string(GameZone.e.DECK_PLAYER)] = _serialize_card_array(cards_in_deck_player)
	data["zones"][GameZone.get_as_string(GameZone.e.DECK_OPPONENT)] = _serialize_card_array(cards_in_deck_opponent)
	data["zones"][GameZone.get_as_string(GameZone.e.EXTRA_DECK_PLAYER)] = _serialize_card_array(cards_in_extra_deck_player)
	
	# Serialize combat zones
	for zone_name in cards_in_combat_zones:
		data["zones"][zone_name] = _serialize_card_array(cards_in_combat_zones[zone_name])
	
	# Serialize positions (CardData ID -> Vector3)
	for card_data in card_positions:
		var card_id = card_data.get_instance_id()
		data["positions"][str(card_id)] = {
			"x": card_positions[card_data].x,
			"y": card_positions[card_data].y,
			"z": card_positions[card_data].z
		}
	
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
	copy.cards_in_hand_player = cards_in_hand_player.duplicate()
	copy.cards_in_hand_opponent = cards_in_hand_opponent.duplicate()
	copy.cards_in_extra_hand_player = cards_in_extra_hand_player.duplicate()
	copy.cards_on_battlefield_player = cards_on_battlefield_player.duplicate()
	copy.cards_on_battlefield_opponent = cards_on_battlefield_opponent.duplicate()
	copy.cards_in_graveyard_player = cards_in_graveyard_player.duplicate()
	copy.cards_in_graveyard_opponent = cards_in_graveyard_opponent.duplicate()
	copy.cards_in_deck_player = cards_in_deck_player.duplicate()
	copy.cards_in_deck_opponent = cards_in_deck_opponent.duplicate()
	copy.cards_in_extra_deck_player = cards_in_extra_deck_player.duplicate()
	
	# Deep copy combat zones
	for zone_name in cards_in_combat_zones:
		copy.cards_in_combat_zones[zone_name] = cards_in_combat_zones[zone_name].duplicate()
	
	# Copy dictionaries
	copy.card_positions = card_positions.duplicate()
	copy.card_to_zone = card_to_zone.duplicate()
	copy.card_to_combat_spot = card_to_combat_spot.duplicate()
	
	return copy

## Debug: Print current state
func print_game_state() -> void:
	print("=== Complete Game State ===")
	print("Life: ", player_life.value, " | Shield: ", player_shield.value, " | Gold: ", player_gold.value)
	print("Turn: ", current_turn.value, " | Danger: ", danger_level.value)
	print("")
	print("Player Hand: ", cards_in_hand_player.size(), " cards")
	print("Opponent Hand: ", cards_in_hand_opponent.size(), " cards")
	print("Player Battlefield: ", cards_on_battlefield_player.size(), " cards")
	print("Opponent Battlefield: ", cards_on_battlefield_opponent.size(), " cards")
	print("Player Graveyard: ", cards_in_graveyard_player.size(), " cards")
	print("Opponent Graveyard: ", cards_in_graveyard_opponent.size(), " cards")
	print("Combat Zones: ", cards_in_combat_zones.size())
	print("Total tracked cards: ", card_to_zone.size())
	print("===========================")
