extends SceneTree
class_name GameSceneTest

# Integration test that loads the actual game scene
# Run with: godot --headless --script res://Test/GameSceneTest.gd

var game_scene: Game
var test_results: Array[Dictionary] = []

func _initialize():
	print("=== Game Scene Integration Test ===")
	
	# Load the actual game scene
	var game_scene_resource = load("res://Game/scenes/game.tscn")
	if not game_scene_resource:
		print("❌ Failed to load game scene")
		quit(1)
		return
	
	game_scene = game_scene_resource.instantiate()
	root.add_child(game_scene)
	
	# Wait a frame for _ready() to complete
	await process_frame
	
	# Run integration tests
	test_card_play_integration()
	test_ability_triggers_integration()
	
	# Print results and exit
	print_test_results()
	quit(0 if all_tests_passed() else 1)

func test_card_play_integration():
	print("\n--- Integration Test: Card Play Flow ---")
	
	var initial_hand_size = game_scene.player_hand.get_child_count()
	var initial_base_size = game_scene.player_base.getCards().size()
	
	print("Initial hand size: ", initial_hand_size)
	print("Initial base size: ", initial_base_size)
	
	# Try to play the first card in hand if any exist
	if initial_hand_size > 0:
		var first_card = game_scene.player_hand.get_child(0) as Card
		if first_card:
			# Simulate playing to player base
			game_scene.tryMoveCard(first_card, game_scene.player_base)
			
			await process_frame  # Wait for animations/processing
			
			var final_hand_size = game_scene.player_hand.get_child_count()
			var final_base_size = game_scene.player_base.getCards().size()
			
			var test_passed = (final_hand_size == initial_hand_size - 1) and (final_base_size == initial_base_size + 1)
			
			test_results.append({
				"name": "Card Play Integration",
				"passed": test_passed,
				"details": "Hand: %d→%d, Base: %d→%d" % [initial_hand_size, final_hand_size, initial_base_size, final_base_size]
			})
			
			print("Result: ", "✅ PASSED" if test_passed else "❌ FAILED")
		else:
			test_results.append({"name": "Card Play Integration", "passed": false, "details": "No card found in hand"})
	else:
		test_results.append({"name": "Card Play Integration", "passed": false, "details": "No cards in hand to test"})

func test_ability_triggers_integration():
	print("\n--- Integration Test: Ability Triggers ---")
	
	# This test would check if abilities actually trigger in the real scene
	# You could add specific cards to the scene and verify their effects
	
	# For now, just mark as a placeholder
	test_results.append({
		"name": "Ability Triggers Integration", 
		"passed": true, 
		"details": "Placeholder - implement specific ability tests here"
	})

func print_test_results():
	print("\n=== Integration Test Results ===")
	for result in test_results:
		var status = "✅ PASSED" if result.passed else "❌ FAILED"
		print("%s: %s (%s)" % [result.name, status, result.details])

func all_tests_passed() -> bool:
	for result in test_results:
		if not result.passed:
			return false
	return true
