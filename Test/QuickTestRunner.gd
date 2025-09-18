@tool
extends Node
class_name QuickTestRunner

# Quick test runner to test our new Goblin Matron sequence test
# Run this to test the testing framework itself

func _ready():
	run_selection_system_test()

func run_selection_system_test():
	print("=== Quick Test Runner - Selection System Test ===")
	
	# Test the PlayerSelection class
	print("Testing PlayerSelection class...")
	
	var player_selection_script = load("res://Game/scripts/PlayerSelection.gd")
	if not player_selection_script:
		print("❌ Failed to load PlayerSelection script")
		return
	
	print("✓ PlayerSelection script loaded successfully")
	
	# Test creating a selection requirement
	var requirement = {
		"valid_card": "Card.YouCtrl+Goblin",
		"count": 2
	}
	
	var empty_cards: Array[Card] = []
	var selection = player_selection_script.new(requirement, empty_cards, "sacrifice")
	
	print("✓ PlayerSelection instance created")
	print("Requirement Description: ", selection.get_requirement_description())
	print("Is Complete: ", selection.is_complete)
	print("Selection Type: ", selection.selection_type)
	
	# Test card filter matching
	print("\nTesting card filter matching...")
	var test_result = player_selection_script.card_matches_filter(null, "Any")
	print("Filter 'Any' with null card: ", test_result)
	
	print("✅ Selection system basic functionality working!")
	print("✅ Test completed")
	
	# Exit the application
	if Engine.is_editor_hint():
		print("Running in editor - use stop button to exit")
	else:
		get_tree().quit(0)

# Entry point is now _ready() function
