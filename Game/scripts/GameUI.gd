extends Control
class_name GameUI

@onready var player_life_label: Label = $PlayerLife
@onready var player_shield_label: Label = $PlayerShield  
@onready var danger_level_label: Label = $DangerLevel
@onready var turn_label: Label = $Turn
@onready var player_point: Label = $PlayerPoint

var game_data: GameData

func _ready():
	# Wait for game data to be set
	pass

func setup_game_data(data: GameData):
	"""Connect to GameData SignalFloat signals"""
	game_data = data
	
	# Connect to SignalFloat value_changed signals
	game_data.player_life.value_changed.connect(_on_player_life_changed)
	game_data.player_shield.value_changed.connect(_on_player_shield_changed)
	game_data.danger_level.value_changed.connect(_on_danger_level_changed)
	game_data.current_turn.value_changed.connect(_on_turn_changed)
	
	# Initial UI update
	_update_all_ui()

func _update_all_ui():
	"""Update all UI elements with current game state"""
	if game_data:
		_on_player_life_changed(game_data.player_life.value, game_data.player_life.value)
		_on_player_shield_changed(game_data.player_shield.value, game_data.player_shield.value)
		_on_danger_level_changed(game_data.danger_level.value, game_data.danger_level.value)
		_on_turn_changed(game_data.current_turn.value, game_data.current_turn.value)

func _on_player_life_changed(new_value: float, old_value: float):
	"""Update player life display"""
	if player_life_label:
		player_life_label.text = "Life: " + str(int(new_value))
	print("Player Life: ", old_value, " -> ", new_value)

func _on_player_shield_changed(new_value: float, old_value: float):
	"""Update player shield display"""
	if player_shield_label:
		player_shield_label.text = "Shield: " + str(int(new_value))
	print("Player Shield: ", old_value, " -> ", new_value)

func _on_danger_level_changed(new_value: float, old_value: float):
	"""Update danger level display"""
	if danger_level_label:
		danger_level_label.text = "Danger: " + str(int(new_value))
	print("Danger Level: ", old_value, " -> ", new_value)

func _on_turn_changed(new_value: float, old_value: float):
	"""Update turn display"""
	if turn_label:
		turn_label.text = "Turn: " + str(int(new_value))
	print("Turn: ", old_value, " -> ", new_value)

func update_player_points(points: int):
	"""Update player points display (not managed by GameData)"""
	if player_point:
		player_point.text = str(points)
