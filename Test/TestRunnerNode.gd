extends Node

# Simple test runner that executes on scene start
# Set this scene as your main scene temporarily to run tests

func _ready():
	print("=== Starting Card Game Tests ===")
	
	# Run all tests by calling the static methods directly
	run_card_interaction_tests()
	
	print("=== Tests Complete - Check Output Above ===")
	
	# Optional: quit after tests
	# get_tree().quit()

func run_card_interaction_tests():
	print("=== Card Interaction Tests ===")
	
	var test_results = []
	
	# Run the old print-based tests (keeping them for now)
	test_goblin_matron_token_creation()
	test_multiple_goblin_matrons()
	test_goblin_matron_no_trigger_on_non_goblin()
	
	# Run the new log-based test
	var goblin_matron_result = test_goblin_matron_play_sequence()
	test_results.append({
		"name": "Goblin Matron Play Sequence",
		"result": goblin_matron_result
	})
	
	# Display results summary
	print("\n=== Test Results Summary ===")
	for test in test_results:
		if test.result.success:
			print("✅ " + test.name + ": PASSED")
		else:
			print("❌ " + test.name + ": FAILED")
			print("   Error: " + test.result.error)
			if test.result.logs.size() > 0:
				print("   Debug logs:")
				for log_entry in test.result.logs:
					print("     " + log_entry)
	
	print("=== Card Interaction Tests Complete ===")

func test_goblin_matron_token_creation():
	print("\n--- Test: Goblin Matron creates token when Goblin is played ---")
	
	# Setup test environment
	var game = GameTestEnvironment.new()
	
	# Add Goblin Matron to player base (on battlefield)
	var matron_card = game.create_test_card("Goblin Matron")
	game.player_base.append(matron_card)
	
	# Add a Goblin card to hand
	var goblin_card = game.create_test_card("Goblin Warchief")  # Assuming this exists
	game.player_hand.append(goblin_card)
	
	print("Initial state:")
	print("  Player Base: ", game.player_base.size(), " cards")
	print("  Hand: ", game.player_hand.size(), " cards")
	
	# Play the Goblin from hand
	var success = game.play_card_from_hand("Goblin Warchief")
	
	print("After playing Goblin:")
	print("  Play successful: ", success)
	print("  Player Base: ", game.player_base.size(), " cards")
	print("  Hand: ", game.player_hand.size(), " cards")
	
	# Assertions
	var matron_triggered = game.assert_ability_triggered("Goblin Matron", "CardPlayed")
	var token_created = game.assert_token_created("Goblin")
	var expected_base_size = 3  # Matron + Played Goblin + Token
	
	print("Results:")
	print("  ✓ Matron triggered: ", matron_triggered)
	print("  ✓ Token created: ", token_created)
	print("  ✓ Correct base size: ", game.assert_player_base_size(expected_base_size))
	
	if matron_triggered and token_created and game.assert_player_base_size(expected_base_size):
		print("  ✅ TEST PASSED")
	else:
		print("  ❌ TEST FAILED")
		game.print_game_state()

func test_multiple_goblin_matrons():
	print("\n--- Test: Multiple Goblin Matrons create multiple tokens ---")
	
	var game = GameTestEnvironment.new()
	
	# Add two Goblin Matrons to player base
	var matron1 = game.create_test_card("Goblin Matron")
	var matron2 = game.create_test_card("Goblin Matron")
	game.player_base.append(matron1)
	game.player_base.append(matron2)
	
	# Add a Goblin to hand
	var goblin_card = game.create_test_card("Goblin Warchief")
	game.player_hand.append(goblin_card)
	
	print("Initial state: 2 Matrons on battlefield, 1 Goblin in hand")
	
	# Play the Goblin
	game.play_card_from_hand("Goblin Warchief")
	
	# Should have: 2 Matrons + 1 Played Goblin + 2 Tokens = 5 cards
	var expected_tokens = game.get_cards_by_name("Goblin").size()
	
	print("Results:")
	print("  Goblin tokens created: ", expected_tokens)
	print("  Total cards in base: ", game.player_base.size())
	print("  Expected: 5 cards (2 Matrons + 1 Goblin + 2 Tokens)")
	
	if game.player_base.size() == 5 and expected_tokens >= 2:
		print("  ✅ TEST PASSED")
	else:
		print("  ❌ TEST FAILED")
		game.print_game_state()

func test_goblin_matron_no_trigger_on_non_goblin():
	print("\n--- Test: Goblin Matron doesn't trigger on non-Goblin cards ---")
	
	var game = GameTestEnvironment.new()
	
	# Add Goblin Matron to player base
	var matron = game.create_test_card("Goblin Matron")
	game.player_base.append(matron)
	
	# Add a non-Goblin card to hand (assuming Sphinx exists and is not a Goblin)
	var sphinx_card = game.create_test_card("Sphinx")
	game.player_hand.append(sphinx_card)
	
	print("Initial state: 1 Matron on battlefield, 1 Sphinx in hand")
	
	# Play the non-Goblin
	game.play_card_from_hand("Sphinx")
	
	# Should have: 1 Matron + 1 Sphinx = 2 cards (no token)
	var token_created = game.assert_token_created("Goblin")
	var matron_triggered = game.assert_ability_triggered("Goblin Matron", "CardPlayed")
	
	print("Results:")
	print("  Token created: ", token_created)
	print("  Matron triggered: ", matron_triggered)
	print("  Total cards in base: ", game.player_base.size())
	
	if not token_created and game.player_base.size() == 2:
		print("  ✅ TEST PASSED - No token created for non-Goblin")
	else:
		print("  ❌ TEST FAILED - Token shouldn't be created")
		game.print_game_state()

func test_goblin_matron_play_sequence() -> Dictionary:
	var logs = []
	var game = GameTestEnvironment.new()
	
	# Add Goblin Matron and a Goblin card to hand
	var matron_card = game.create_test_card("Goblin Matron")
	var goblin_card = game.create_test_card("Goblin Warchief")
	game.player_hand.append(matron_card)
	game.player_hand.append(goblin_card)
	
	logs.append("Initial state: Hand: 2 cards (Goblin Matron, Goblin Warchief), Player Base: " + str(game.player_base.size()) + " cards")
	
	# Step 1: Play Goblin Matron from hand to player base
	var matron_play_success = game.play_card_from_hand("Goblin Matron")
	logs.append("After playing Goblin Matron: Play successful: " + str(matron_play_success) + ", Hand: " + str(game.player_hand.size()) + " cards, Player Base: " + str(game.player_base.size()) + " cards")
	logs.append("Cards in base: " + str(game.player_base.map(func(c): return c.cardData.cardName)))
	
	if not matron_play_success:
		return {"success": false, "error": "Failed to play Goblin Matron from hand", "logs": logs}
	
	# Step 2: Play Goblin Warchief from hand to player base
	var goblin_play_success = game.play_card_from_hand("Goblin Warchief")
	logs.append("After playing Goblin Warchief: Play successful: " + str(goblin_play_success) + ", Hand: " + str(game.player_hand.size()) + " cards, Player Base: " + str(game.player_base.size()) + " cards")
	logs.append("Cards in base: " + str(game.player_base.map(func(c): return c.cardData.cardName)))
	
	if not goblin_play_success:
		return {"success": false, "error": "Failed to play Goblin Warchief from hand", "logs": logs}
	
	# Analyze final state
	var total_cards_in_play = game.player_base.size()
	var goblin_cards = game.get_cards_by_name("goblin")  # Token goblins (lowercase)
	var goblin_warchief_cards = game.get_cards_by_name("Goblin Warchief")  # Played goblin
	var total_goblin_type_cards = goblin_cards.size() + goblin_warchief_cards.size()
	
	logs.append("Final Analysis: Total cards in play: " + str(total_cards_in_play))
	logs.append("Goblin tokens (lowercase): " + str(goblin_cards.size()))
	logs.append("Goblin Warchief cards: " + str(goblin_warchief_cards.size()))
	logs.append("Total Goblin-type cards: " + str(total_goblin_type_cards))
	logs.append("Expected: 4 total cards (Matron + Warchief + 2 tokens), 3 Goblin-type cards")
	
	# Assertions
	var matron_triggered = game.assert_ability_triggered("Goblin Matron", "CardPlayed")
	var expected_total_cards = 4  # Matron + Warchief + 2 Tokens (Matron triggers on both Goblin plays)
	var expected_goblin_count = 3  # Warchief + 2 Tokens
	
	logs.append("Matron triggered on Goblin play: " + str(matron_triggered))
	logs.append("Exactly 3 cards in play: " + str(total_cards_in_play == expected_total_cards) + " (expected: " + str(expected_total_cards) + ", actual: " + str(total_cards_in_play) + ")")
	logs.append("Exactly 2 Goblin-type cards: " + str(total_goblin_type_cards == expected_goblin_count) + " (expected: " + str(expected_goblin_count) + ", actual: " + str(total_goblin_type_cards) + ")")
	
	if not matron_triggered:
		logs.append("Trigger History: " + str(game.ability_triggers_history))
		return {"success": false, "error": "Goblin Matron ability did not trigger when Goblin was played", "logs": logs}
	
	if total_cards_in_play != expected_total_cards:
		return {"success": false, "error": "Expected " + str(expected_total_cards) + " cards in play but found " + str(total_cards_in_play), "logs": logs}
	
	if total_goblin_type_cards != expected_goblin_count:
		return {"success": false, "error": "Expected " + str(expected_goblin_count) + " Goblin-type cards but found " + str(total_goblin_type_cards), "logs": logs}
	
	return {"success": true, "error": "", "logs": []}
