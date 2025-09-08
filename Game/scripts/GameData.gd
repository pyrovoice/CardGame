extends RefCounted
class_name GameData

# Player stats using SignalFloat
var player_life: SignalFloat
var player_shield: SignalFloat

# Game state using SignalFloat
var danger_level: SignalFloat
var current_turn: SignalFloat

func _init():
	# Initialize SignalFloat values
	player_life = SignalFloat.new(3.0)
	player_shield = SignalFloat.new(3.0)
	danger_level = SignalFloat.new(5.0)
	current_turn = SignalFloat.new(1.0)

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

func heal_player(amount: float):
	"""Heal the player's life"""
	player_life.value += amount

func restore_shield(amount: float):
	"""Restore the player's shield"""
	player_shield.value += amount

func start_new_turn():
	"""Start a new turn and increase danger level"""
	current_turn.value += 1
	increase_danger_level()

func is_player_defeated() -> bool:
	"""Check if the player has been defeated"""
	return player_life.value <= 0

func get_game_state() -> Dictionary:
	"""Get the current game state as a dictionary"""
	return {
		"player_life": player_life.value,
		"player_shield": player_shield.value,
		"danger_level": danger_level.value,
		"current_turn": current_turn.value
	}

func reset_game():
	"""Reset the game to initial state"""
	player_life.value = 3
	player_shield.value = 3
	danger_level.value = 5
	current_turn.value = 1
