extends RefCounted
class_name GameData

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
	var finds = combatLocationDatas.filter(func(c:CombatLocationData): return c.relatedLocation == combat_zone)
	if finds.size()==0:
		return
	var data: CombatLocationData = finds[0]
	return data.isCombatResolved
