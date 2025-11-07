extends Control
class_name TestManager

var game: Game
var test_results: Array[Dictionary] = []
var session_test_results: Dictionary = {}  # Track results by test name for the session
var test_runner: TestGameRunner  # Reference to the test runner
var current_test_failed: bool = false  # Track if current test failed
var current_test_error: String = ""    # Store current test error message

# UI References
@onready var run_all_button: Button = $AllTests
@onready var run_failed_button: Button = $FailedTests  
@onready var test_grid_container: GridContainer = $GridContainer

# === CUSTOM ASSERT SYSTEM ===

func assert_test(condition: bool, message: String = "Assertion failed") -> bool:
	"""Custom assert that allows tests to fail gracefully"""
	if not condition:
		current_test_failed = true
		current_test_error = message
		print("❌ ASSERTION FAILED: ", message)
		return false
	return true

func assert_test_equal(actual, expected, message: String = "") -> bool:
	"""Assert that two values are equal"""
	if actual != expected:
		var error_msg = message if message != "" else "Expected %s but got %s" % [expected, actual]
		return assert_test(false, error_msg)
	return true

func assert_test_not_null(value, message: String = "") -> bool:
	"""Assert that value is not null"""
	var error_msg = message if message != "" else "Value should not be null"
	return assert_test(value != null, error_msg)

func assert_test_null(value, message: String = "") -> bool:
	"""Assert that value is null"""
	var error_msg = message if message != "" else "Value should be null"
	return assert_test(value == null, error_msg)

func assert_test_true(condition: bool, message: String = "") -> bool:
	"""Assert that condition is true"""
	var error_msg = message if message != "" else "Condition should be true"
	return assert_test(condition, error_msg)

func assert_test_false(condition: bool, message: String = "") -> bool:
	"""Assert that condition is false"""
	var error_msg = message if message != "" else "Condition should be false"
	return assert_test(not condition, error_msg)

func _ready():
	# Connect buttons
	run_all_button.pressed.connect(_on_run_all_tests)
	run_failed_button.pressed.connect(_on_run_failed_tests)
	
	# Initialize UI
	_populate_test_buttons()

func _on_run_all_tests():
	"""Button handler to run all tests"""
	if test_runner:
		game = test_runner.ensure_game_loaded()
	await runTests()
	_update_test_button_states()
	if test_runner:
		test_runner.cleanup_game()  # Destroy game after all tests complete
		game = null  # Clear reference to destroyed game
		test_runner.show_test_manager()

func _on_run_failed_tests():
	"""Button handler to run only failed tests"""
	if test_runner:
		game = test_runner.ensure_game_loaded()
	await runFailedTests()
	_update_test_button_states()
	if test_runner:
		test_runner.cleanup_game()  # Destroy game after failed tests complete
		game = null  # Clear reference to destroyed game
		test_runner.show_test_manager()

func _populate_test_buttons():
	"""Create individual buttons for each test method"""
	# Clear existing buttons
	for child in test_grid_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	
	var test_methods = _discover_test_methods()
	
	for test_method in test_methods:
		var button = Button.new()
		button.text = test_method.replace("test_", "").replace("_", " ").capitalize()
		button.name = test_method
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Connect to individual test runner
		button.pressed.connect(_on_individual_test_pressed.bind(test_method))
		
		# Set initial color based on session results
		_update_button_appearance(button, test_method)
		
		test_grid_container.add_child(button)

func _on_individual_test_pressed(test_method: String):
	"""Run a single test when its button is pressed"""
	print("=== Running Individual Test: ", test_method, " ===")
	
	if test_runner:
		game = test_runner.ensure_game_loaded()
	
	var result = await _run_single_test(test_method)
	
	# Update session results
	session_test_results[test_method] = result
	
	# Update button appearance
	var button = test_grid_container.get_node(test_method)
	_update_button_appearance(button, test_method)
	
	# Print result
	if result.passed:
		print("✅ PASSED: ", test_method, " (", result.duration_ms, "ms)")
	else:
		print("❌ FAILED: ", test_method)
		print("   Error: ", result.error)
	
	if test_runner:
		test_runner.cleanup_game()  # Destroy game after individual test completes
		game = null  # Clear reference to destroyed game
		test_runner.show_test_manager()

func _update_test_button_states():
	"""Update all test button appearances based on session results"""
	for child in test_grid_container.get_children():
		if child is Button:
			_update_button_appearance(child, child.name)

func _update_button_appearance(button: Button, test_method: String):
	"""Update button color based on test result"""
	if test_method in session_test_results:
		var result = session_test_results[test_method]
		if result.passed:
			button.modulate = Color.GREEN
			button.tooltip_text = "PASSED (" + str(result.duration_ms) + "ms)"
		else:
			button.modulate = Color.RED
			button.tooltip_text = "FAILED: " + result.error
	else:
		button.modulate = Color.WHITE
		button.tooltip_text = "Not run yet"

func runFailedTests():
	"""Run only the tests that failed in the current session"""
	print("=== Running Failed Tests ===")
	
	var failed_tests = []
	for test_name in session_test_results.keys():
		var result = session_test_results[test_name]
		if not result.passed:
			failed_tests.append(test_name)
	
	if failed_tests.is_empty():
		print("No failed tests to rerun!")
		return {"passed": 0, "failed": 0, "results": []}
	
	test_results.clear()
	var passed = 0
	var failed = 0
	
	for test_method in failed_tests:
		print("\n--- Re-running: ", test_method, " ---")
		
		var result = await _run_single_test(test_method)
		test_results.append(result)
		session_test_results[test_method] = result
		
		if result.passed:
			print("✅ NOW PASSED: ", test_method, " (", result.duration_ms, "ms)")
			passed += 1
		else:
			print("❌ STILL FAILED: ", test_method)
			print("   Error: ", result.error)
			failed += 1
	
	print("\n=== Failed Tests Rerun Results ===")
	print("Now Passed: ", passed)
	print("Still Failed: ", failed)
	print("Total Rerun: ", passed + failed)
	
	return {"passed": passed, "failed": failed, "results": test_results}

func runTests():
	"""Automatically discovers and runs all test methods"""
	print("=== Starting Test Suite ===")
	test_results.clear()
	
	var test_methods = _discover_test_methods()
	var passed = 0
	var failed = 0
	
	for test_method in test_methods:
		print("\n--- Running: ", test_method, " ---")
		
		var result = await _run_single_test(test_method)
		test_results.append(result)
		
		# Update session results
		session_test_results[test_method] = result
		
		if result.passed:
			print("✅ PASSED: ", test_method, " (", result.get("duration_ms", 0), "ms)")
			passed += 1
		else:
			print("❌ FAILED: ", test_method)
			print("   Error: ", result.error)
			failed += 1
	
	print("\n=== Test Results ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("Total: ", passed + failed)
	
	return {"passed": passed, "failed": failed, "results": test_results}

func _discover_test_methods() -> Array[String]:
	"""Automatically find all methods that start with 'test'"""
	var test_methods: Array[String] = []
	var method_list = get_method_list()
	
	for method_info in method_list:
		var method_name = method_info["name"]
		if method_name.begins_with("test") and method_name != "test_results":
			test_methods.append(method_name)
	
	return test_methods

func _run_single_test(test_method: String) -> Dictionary:
	"""Run a single test and capture its result"""
	var result = {
		"name": test_method,
		"passed": false,
		"error": "",
		"start_time": Time.get_ticks_msec()
	}
	
	# Reset test failure tracking
	current_test_failed = false
	current_test_error = ""
	
	# Run beforeEach setup
	await beforeEach()
	
	# Execute the test method
	if has_method(test_method):
		var test_result = await call(test_method)
		
		# Check if test failed via custom assert or returned false
		if current_test_failed:
			result.passed = false
			result.error = current_test_error
		elif test_result == false:
			result.passed = false
			result.error = "Test returned false"
		else:
			result.passed = true
	else:
		result.error = "Test method '" + test_method + "' not found"
	
	result["end_time"] = Time.get_ticks_msec()
	result["duration_ms"] = result.end_time - result.start_time
	
	return result

func _on_test_error():
	"""Handle test errors"""
	# Custom error handler if needed
	pass
	
func resetState():
	"""Reset game state to have empty everything"""
	if not game:
		return
		
	# Clear all zones
	for child in game.player_hand.get_children():
		child.queue_free()
	for child in game.opponent_hand.get_children():
		child.queue_free()
	for child in game.player_base.get_children():
		if child is Card:
			child.queue_free()
	
	# Clear all combat zones
	for combat_zone in game.combatZones:
		if combat_zone is CombatZone:
			# Clear ally spots
			for ally_spot in combat_zone.allySpots:
				var card = ally_spot.getCard()
				if card:
					card.queue_free()
			
			# Clear enemy spots
			for enemy_spot in combat_zone.ennemySpots:
				var card = enemy_spot.getCard()
				if card:
					card.queue_free()
	
	# Reset game data including combat resolution states
	game.game_data.player_gold.setValue(3)
	game.game_data.opponent_gold.setValue(3)
	game.game_data.player_life.setValue(10)
	game.game_data.danger_level.setValue(1)
	
	# Reset combat resolution states for all zones
	for combat_zone in game.combatZones:
		if combat_zone is CombatZone:
			game.game_data.set_combat_resolved(combat_zone, false)
			# Reset combat data (capture values) for each zone
			game.game_data.reset_combat_zone_data(combat_zone)
			# Reset button display
			combat_zone.update_resolve_fight_display(false)
	
	# Wait a frame for cleanup
	await get_tree().process_frame

func beforeEach():
	await resetState()

# === TEST HELPER METHODS ===

func createTestCard(card_name: String, player_controlled: bool = true) -> Card:
	"""Helper to create a card for testing"""
	var card_data = CardLoaderAL.getCardByName(card_name)
	if not assert_test_not_null(card_data, "Card not found: " + card_name):
		return null
	return game.createCardFromData(card_data, player_controlled)

func addCardToHand(card: Card):
	"""Helper to add card to player hand"""
	card.reparent(game.player_hand)
	
func addCardToExtraDeck(card: CardData):
	game.extra_deck.cards.push_back(card)
	
func setPlayerGold(amount: int):
	"""Helper to set player gold"""
	game.game_data.player_gold.setValue(amount)

func getCardsInPlay() -> Array[Card]:
	"""Helper to get all cards in play"""
	return game.player_base.getCards()

func assertCardCount(expected: int, zone: String = "play") -> bool:
	"""Assert the number of cards in a specific zone"""
	var actual: int
	match zone:
		"play":
			actual = getCardsInPlay().size()
		"hand":
			actual = game.player_hand.get_child_count()
		_:
			return assert_test(false, "Unknown zone: " + zone)
	
	return assert_test_equal(actual, expected, "Expected %d cards in %s, but found %d" % [expected, zone, actual])

func assertCardExists(card_name: String, zone: String = "play") -> bool:
	"""Assert that a specific card exists in a zone"""
	var found = false
	match zone:
		"play":
			for card in getCardsInPlay():
				if card.cardData.cardName == card_name:
					found = true
					break
		"hand":
			for card in game.player_hand.get_children():
				if card is Card and card.cardData.cardName == card_name:
					found = true
					break
	
	return assert_test_true(found, "Card '%s' not found in %s" % [card_name, zone])

func clickCombatButton(combat_zone: CombatZone):
	"""Helper method to click a combat zone's resolve button and wait for completion"""
	var resolve_button = combat_zone.resolve_fight_button
	game._on_left_click(resolve_button)
	var counter = 10
	while counter>0 && game.game_data.get_combat_zone_data(combat_zone).isCombatResolved.value == false:
		counter -= 1
		await get_tree().create_timer(0.5).timeout

# === ACTUAL TESTS ===

func test_card_creation():
	"""Test that cards can be created from card data"""
	var card = createTestCard("goblin pair")
	if not assert_test_not_null(card, "Card should be created"):
		return false
	if not assert_test_equal(card.cardData.cardName, "Goblin pair", "Card should have correct name"):
		return false
	return true

func test_failure_example():
	"""Example test that demonstrates failure handling"""
	if not assert_test_true(false, "This test is designed to fail for demonstration"):
		return false
	return true

func test_card_play_basic():
	"""Test basic card playing functionality"""
	var card = createTestCard("goblin pair")
	addCardToHand(card)
	setPlayerGold(3)
	await get_tree().process_frame
	if not assertCardCount(0, "play"):
		return false
	if not assertCardCount(1, "hand"):
		return false
	
	await game.tryPlayCard(card, game.player_base)
	
	if not assertCardCount(2, "play"):
		return false
	if not assertCardCount(0, "hand"):
		return false
	if not assertCardExists("Goblin pair", "play"):
		return false

func test_insufficient_gold():
	"""Test that cards can't be played without enough gold"""
	var card = createTestCard("goblin pair")  # costs 3
	addCardToHand(card)
	setPlayerGold(0)  # Not enough
	
	await game.tryPlayCard(card, game.player_base)
	
	# Card should still be in hand
	if not assertCardCount(0, "play"):
		return false
	if not assertCardCount(1, "hand"):
		return false
	
func test_animation_completion():
	"""Test that card animations complete properly"""
	var card = createTestCard("goblin pair")
	addCardToHand(card)
	setPlayerGold(3)
	
	var start_time = Time.get_ticks_msec()
	await game.tryPlayCard(card, game.player_base)
	var end_time = Time.get_ticks_msec()
	
	# Should take some time for animation
	if not assert_test(end_time - start_time > 100, "Animation should take some time"):
		return false
	assertCardExists("Goblin pair", "play")

# Add more tests as needed...

func test_goblin_pair():
	"""Test Goblin Pair card creation and spawning"""
	var cardData = CardLoaderAL.getCardByName("goblin pair")
	var c = game.createCardFromData(cardData, true)
	addCardToHand(c)
	game.game_data.player_gold.setValue(99)
	await game.tryPlayCard(c, game.player_base)
	var cardsInPlay = game.player_base.getCards()
	if not assert_test_equal(cardsInPlay.size(), 2, "Goblin Pair should spawn 2 cards"):
		return false

func test_goblin_boss_extra_deck_casting():
	"""Test playing Goblin Boss from extra deck with proper selection"""
	# Setup: Give player plenty of gold
	setPlayerGold(99)
	
	# Step 1: Play 2 Goblin Pairs to get 4 goblins total (2 pairs + 2 tokens)
	addCardToExtraDeck(CardLoaderAL.getCardByName("Goblin Boss"))
	var goblin_pair_1 = createTestCard("goblin pair")
	addCardToHand(goblin_pair_1)
	
	# Play first Goblin Pair and wait for animation to complete
	await game.tryPlayCard(goblin_pair_1, game.player_base)
	if not assertCardCount(2, "play"):  # Should have 2 goblins now
		return false
	
	
	# Step 2: Assert that Goblin Boss appears in extra deck display
	var extra_deck_cards = game.extra_deck_display.get_children().filter(func(child): return child is Card)
	var goblin_boss_found = false
	var goblin_boss_card: Card = null
	
	for card in extra_deck_cards:
		if card.cardData.cardName == "Goblin Boss":
			goblin_boss_found = true
			goblin_boss_card = card
			break
	
	if not assert_test_true(goblin_boss_found, "Goblin Boss should be displayed in extra deck when 2+ goblins are in play"):
		return false
	
	# Step 3: Attempt to play Goblin Boss from extra deck
	# This should trigger selection for the additional cost (sacrifice 2 goblins)
	var goblins_before = getCardsInPlay().filter(func(card:Card): return card.cardData.hasSubtype("Goblin")).size()
	if not assert_test(goblins_before >= 2, "Should have at least 2 goblins before casting boss"):
		return false
	
	# Get the first 2 goblin cards for selection
	var goblins_in_play = getCardsInPlay().filter(func(card): return card.cardData.hasSubtype("Goblin"))
	if not assert_test(goblins_in_play.size() >= 2, "Should have at least 2 goblins to sacrifice"):
		return false
	
	# Prepare selection data with the two goblins to sacrifice
	var selection_data = {
		"additional_cost_selections": [goblins_in_play[0], goblins_in_play[1]] as Array[Card],
		"spell_targets": [] as Array[Card],
		"cancelled": false
	}
	
	await game.tryPlayCard(goblin_boss_card, game.player_base, selection_data)
	
	# Step 4: Assert final state
	var final_cards = getCardsInPlay()
	var boss_found = final_cards.filter(func(c: Card): return c.cardData.cardName == "Goblin Boss").size() >= 1
	
	if not assert_test_true(boss_found, "Goblin Boss should be in play"):
		return false
	if not assert_test_equal(final_cards.size(), 1, "Should have exactly 1 card in play: Goblin Boss"):
		return false

func test_combat_zone_button_click():
	"""Test clicking combat zone resolve button changes zone resolution state"""
	# Setup: Create a creature and place it in a combat zone
	var card = createTestCard("goblin pair")
	setPlayerGold(99)
	
	# Get the first combat zone and place the card there
	var combat_zone = game.combatZones[0] as CombatZone
	var first_ally_spot = combat_zone.getFirstEmptyLocation(true)
	if not assert_test_not_null(first_ally_spot, "Should have an empty ally spot available"):
		return false
	
	# Place the card directly in the combat zone
	first_ally_spot.setCard(card)
	await get_tree().process_frame  # Wait for the UI to update
	
	# Verify the card is in the combat zone
	if not assert_test_equal(first_ally_spot.getCard(), card, "Card should be placed in the combat zone"):
		return false
	
	# Check initial state - combat should not be resolved
	if not assert_test_false(game.game_data.is_combat_resolved(combat_zone), "Combat should initially be unresolved"):
		return false
	
	# Click the combat button and wait for resolution
	await clickCombatButton(combat_zone)
	
	# Verify the combat zone state has changed - it should now be resolved
	if not assert_test_true(game.game_data.is_combat_resolved(combat_zone), "Combat should be resolved after clicking the button"):
		return false
	
	# Verify the button display has been updated
	var resolve_button = combat_zone.resolve_fight_button
	if not assert_test_equal(resolve_button.resolve_fight.modulate, Color.GREEN, "Button color should change to green after resolution"):
		return false

func test_combat_location_independence():
	"""Test that attacking one combat location doesn't affect another location's state"""
	# Setup: Create two simple goblin cards
	var goblin1 = createTestCard("goblin")
	var goblin2 = createTestCard("goblin")
	addCardToHand(goblin1)
	addCardToHand(goblin2)
	
	# Get two different combat zones
	var combat_zone_1 = game.combatZones[0] as CombatZone
	var combat_zone_2 = game.combatZones[1] as CombatZone
	if not assert_test(combat_zone_1 != combat_zone_2, "Should have different combat zones"):
		return false
	
	# Play goblin1 to first combat location
	var first_ally_spot_1 = combat_zone_1.getFirstEmptyLocation(true)
	if not assert_test_not_null(first_ally_spot_1, "First combat zone should have an empty ally spot"):
		return false
	await game.tryPlayCard(goblin1, first_ally_spot_1)
	
	# Play goblin2 to second combat location
	var first_ally_spot_2 = combat_zone_2.getFirstEmptyLocation(true)
	if not assert_test_not_null(first_ally_spot_2, "Second combat zone should have an empty ally spot"):
		return false
	await game.tryPlayCard(goblin2, first_ally_spot_2)
	
	# Verify both cards are in their respective zones
	if not assert_test_equal(first_ally_spot_1.getCard(), goblin1, "Goblin1 should be in first combat zone"):
		return false
	if not assert_test_equal(first_ally_spot_2.getCard(), goblin2, "Goblin2 should be in second combat zone"):
		return false
	
	# Check initial state - both combats should be unresolved
	if not assert_test_false(game.game_data.is_combat_resolved(combat_zone_1), "Combat zone 1 should initially be unresolved"):
		return false
	if not assert_test_false(game.game_data.is_combat_resolved(combat_zone_2), "Combat zone 2 should initially be unresolved"):
		return false
	
	# Store initial combat zone data for comparison
	var initial_zone_2_data = game.game_data.get_combat_zone_data(combat_zone_2)
	var initial_player_capture_current = initial_zone_2_data.player_capture_current
	
	# Click the first combat zone's button to resolve it
	await clickCombatButton(combat_zone_1)
	
	# Verify only the first combat zone was resolved
	if not assert_test_true(game.game_data.is_combat_resolved(combat_zone_1), "Combat zone 1 should be resolved after clicking its button"):
		return false
	if not assert_test_false(game.game_data.is_combat_resolved(combat_zone_2), "Combat zone 2 should remain unresolved"):
		return false
	
	# Get the resolve fight buttons from both combat zones for button state verification
	var resolve_button_1 = combat_zone_1.resolve_fight_button
	var resolve_button_2 = combat_zone_2.resolve_fight_button
	if not assert_test_equal(resolve_button_1.resolve_fight.text, "DONE", "Button 1 text should change to DONE after resolution"):
		return false
	if not assert_test_equal(resolve_button_1.resolve_fight.modulate, Color.GREEN, "Button 1 color should change to green after resolution"):
		return false
	if not assert_test_equal(resolve_button_2.resolve_fight.text, "FIGHT", "Button 2 text should remain FIGHT"):
		return false
	if not assert_test_equal(resolve_button_2.resolve_fight.modulate, Color.WHITE, "Button 2 color should remain white"):
		return false
	
	# Verify that the second combat zone's data in GameData hasn't changed
	var final_zone_2_data = game.game_data.get_combat_zone_data(combat_zone_2)
	if not assert_test_equal(final_zone_2_data.player_capture_current, initial_player_capture_current, 
		"Second combat zone's player_capture_current should not have changed"):
		return false
