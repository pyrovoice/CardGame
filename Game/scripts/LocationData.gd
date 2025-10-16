extends RefCounted
class_name LocationData

# Location-specific capture data
var player_capture_threshold: SignalInt
var opponent_capture_threshold: SignalInt
var playerLocationCaptureValue: SignalInt
var opponentLocationCaptureValue: SignalInt

# Combat resolution tracking for this location
var combatResolved: bool = false

# Location identifier
var location_index: int

func _init(index: int, initial_threshold: int = 10):
	location_index = index
	
	# Initialize SignalInt values
	player_capture_threshold = SignalInt.new(initial_threshold)
	opponent_capture_threshold = SignalInt.new(initial_threshold)
	playerLocationCaptureValue = SignalInt.new(0)
	opponentLocationCaptureValue = SignalInt.new(0)

func reset_capture_values():
	"""Reset capture values for this location after it's been captured"""
	playerLocationCaptureValue.setValue(0)
	opponentLocationCaptureValue.setValue(0)

func increase_capture_thresholds(amount: int = 5):
	"""Increase capture thresholds for this location"""
	var current_threshold = player_capture_threshold.getValue()
	var new_threshold = current_threshold + amount
	
	player_capture_threshold.setValue(new_threshold)
	opponent_capture_threshold.setValue(new_threshold)

func is_player_capture_reached() -> bool:
	"""Check if player has reached capture threshold"""
	return playerLocationCaptureValue.getValue() >= player_capture_threshold.getValue()

func is_opponent_capture_reached() -> bool:
	"""Check if opponent has reached capture threshold"""
	return opponentLocationCaptureValue.getValue() >= opponent_capture_threshold.getValue()

func add_player_capture_damage(damage: int):
	"""Add damage to player's capture progress"""
	if damage > 0:
		playerLocationCaptureValue.setValue(
			playerLocationCaptureValue.getValue() + damage
		)

func add_opponent_capture_damage(damage: int):
	"""Add damage to opponent's capture progress"""
	if damage > 0:
		opponentLocationCaptureValue.setValue(
			opponentLocationCaptureValue.getValue() + damage
		)

func reset_combat_resolution():
	"""Reset combat resolution flag"""
	combatResolved = false

func set_combat_resolved(resolved: bool):
	"""Set combat resolution status"""
	combatResolved = resolved

func is_combat_resolved() -> bool:
	"""Check if combat has been resolved for this location"""
	return combatResolved

func get_location_name() -> String:
	"""Get human-readable location name"""
	return "Location " + str(location_index + 1)

func debug_location_state():
	"""Debug function to print location state"""
	print("=== ", get_location_name(), " ===")
	print("Player Capture: ", playerLocationCaptureValue.getValue(), "/", player_capture_threshold.getValue())
	print("Opponent Capture: ", opponentLocationCaptureValue.getValue(), "/", opponent_capture_threshold.getValue())
	print("Combat Resolved: ", combatResolved)
	print("========================")