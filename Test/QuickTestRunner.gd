@tool
extends Node
class_name QuickTestRunner

# Quick test runner to test our new Goblin Matron sequence test
# Run this to test the testing framework itself

func _ready():
	run_goblin_test()

func run_goblin_test():
	print("=== Quick Test Runner - Goblin Matron Sequence ===")
	
	# Try to create a simple test environment to verify everything works
	print("Testing class loading...")
	
	# Test if we can load the test classes
	var test_card_script = load("res://Test/TestCard.gd")
	var game_env_script = load("res://Test/GameTestEnvironment.gd")
	var card_test_script = load("res://Test/CardInteractionTest.gd")
	
	if test_card_script:
		print("✓ TestCard loaded successfully")
	else:
		print("❌ Failed to load TestCard")
		return
	
	if game_env_script:
		print("✓ GameTestEnvironment loaded successfully")
	else:
		print("❌ Failed to load GameTestEnvironment")
		return
		
	if card_test_script:
		print("✓ CardInteractionTest loaded successfully")
	else:
		print("❌ Failed to load CardInteractionTest")
		return
	
	print("\nAttempting to run just the new Goblin Matron sequence test...")
	
	# Try to run just our specific test
	var result = CardInteractionTest.test_goblin_matron_play_sequence()
	
	if result.success:
		print("✅ Test PASSED!")
	else:
		print("❌ Test FAILED: " + result.error)
	
	print("✅ Test completed - exiting...")
	
	# Exit the application
	if Engine.is_editor_hint():
		print("Running in editor - use stop button to exit")
	else:
		# Exit with appropriate code: 0 for success, 1 for failure
		var exit_code = 0 if result.success else 1
		get_tree().quit(exit_code)

# Entry point is now _ready() function
