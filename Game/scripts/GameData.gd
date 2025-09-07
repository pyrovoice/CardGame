extends RefCounted
class_name GameData

# Player stats
var player_life: int = 3
var player_shield: int = 3

# Game state
var danger_level: int = 5
var current_turn: int = 1

signal danger_level_changed(new_level: int)
signal player_life_changed(new_life: int)
signal player_shield_changed(new_shield: int)
signal turn_started(turn_number: int)

func _init():
	pass

func increase_danger_level():
	"""Increase the danger level by 1 each turn"""
	danger_level += 1
	danger_level_changed.emit(danger_level)

func damage_player(amount: int):
	"""Apply damage to the player, shield absorbs damage first"""
	var remaining_damage = amount
	
	# Shield absorbs damage first
	if player_shield > 0:
		var shield_damage = min(player_shield, remaining_damage)
		player_shield -= shield_damage
		remaining_damage -= shield_damage
		player_shield_changed.emit(player_shield)
	
	# Remaining damage goes to life
	if remaining_damage > 0:
		player_life -= remaining_damage
		player_life_changed.emit(player_life)

func heal_player(amount: int):
	"""Heal the player's life"""
	player_life += amount
	player_life_changed.emit(player_life)

func restore_shield(amount: int):
	"""Restore the player's shield"""
	player_shield += amount
	player_shield_changed.emit(player_shield)

func start_new_turn():
	"""Start a new turn and increase danger level"""
	current_turn += 1
	increase_danger_level()
	turn_started.emit(current_turn)

func is_player_defeated() -> bool:
	"""Check if the player has been defeated"""
	return player_life <= 0

func get_game_state() -> Dictionary:
	"""Get the current game state as a dictionary"""
	return {
		"player_life": player_life,
		"player_shield": player_shield,
		"danger_level": danger_level,
		"current_turn": current_turn
	}

func reset_game():
	"""Reset the game to initial state"""
	player_life = 3
	player_shield = 3
	danger_level = 5
	current_turn = 1
	
	# Emit all signals to update UI
	player_life_changed.emit(player_life)
	player_shield_changed.emit(player_shield)
	danger_level_changed.emit(danger_level)
	turn_started.emit(current_turn)
