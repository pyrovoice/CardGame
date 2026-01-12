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
@onready var failed_tests_2: Button = $FailedTests2

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
	# Use == for comparison to handle type conversions gracefully
	var equals = (actual == expected)
	if not equals:
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
	# Set fast animation speed for testing (10x normal speed)
	CardAnimator.ANIMATION_SPEED = 10.0
	print("🏃 Set animation speed to 10x for testing")
	
	# Connect buttons
	run_all_button.pressed.connect(_on_run_all_tests)
	run_failed_button.pressed.connect(_on_run_failed_tests)
	failed_tests_2.pressed.connect(_on_run_until_failure)
	
	# Initialize UI
	_populate_test_buttons()

func _on_run_all_tests():
	"""Button handler to run all tests"""
	await runTests()
	_update_test_button_states()
	_restore_animation_speed()
	if test_runner:
		await test_runner.cleanup_game()  # Final cleanup after all tests
		game = null  # Clear reference to destroyed game
		test_runner.show_test_manager()

func _on_run_failed_tests():
	"""Button handler to run only failed tests"""
	await runFailedTests()
	_update_test_button_states()
	_restore_animation_speed()
	if test_runner:
		await test_runner.cleanup_game()  # Final cleanup after failed tests
		game = null  # Clear reference to destroyed game
		test_runner.show_test_manager()

func _on_run_until_failure():
	"""Button handler to run all tests until first failure"""
	await runTestsUntilFailure()
	_update_test_button_states()
	_restore_animation_speed()
	if test_runner:
		await test_runner.cleanup_game()  # Final cleanup
		game = null  # Clear reference to destroyed game
		test_runner.show_test_manager()

func _restore_animation_speed():
	"""Restore normal animation speed after testing"""
	CardAnimator.ANIMATION_SPEED = 1.0
	print("🐌 Restored animation speed to normal (1.0x)")

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
		await test_runner.cleanup_game()  # Final cleanup after individual test
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

func runTestsUntilFailure():
	"""Run all tests in order and stop at the first failure"""
	print("=== Running Tests Until First Failure ===")
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
			print("\n⚠️ Stopping execution at first failure")
			break  # Stop at first failure
	
	print("\n=== Test Results (Stopped on Failure) ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("Total Run: ", passed + failed)
	print("Total Tests: ", test_methods.size())
	
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
	
	# Create fresh game instance for this test
	if test_runner:
		await test_runner.cleanup_game()
		game = await test_runner.ensure_game_loaded()
	
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

func createCardFromName(card_name: String, player_controlled: bool = true) -> Card:
	"""Universal helper to create a card from either token or card name"""
	var card_data = CardLoaderAL.getCardByName(card_name)
	if not assert_test_not_null(card_data, "Card/token not found: " + card_name):
		return null
	
	var card = game.createCardFromData(CardLoaderAL.duplicateCardScript(card_data), player_controlled)
	if not assert_test_not_null(card, "Should be able to create card: " + card_name):
		return null
	
	# Set animator state correctly for player-controlled cards
	if player_controlled and card:
		card.getAnimator().start_player_control()
	
	return card

func addCardToHand(card: Card):
	"""Helper to add card to player hand"""
	GameUtility.reparentWithoutMoving(card, game.player_hand)
	
func addCardToExtraDeck(card: CardData):
	game.extra_deck.cards.push_back(card)

func addCardToDeck(card_data: CardData, player_deck: bool = true):
	"""Helper to add card to deck"""
	var deck = game.deck if player_deck else game.deck_opponent
	# Set proper ownership flag for the card data
	card_data.playerOwned = player_deck
	deck.cards.push_back(card_data)
	deck.update_size()
	
func setPlayerGold(amount: int):
	"""Helper to set player gold"""
	game.game_data.player_gold.setValue(amount)

func simulateCardSelection(target_card: Card) -> bool:
	"""Simulate player selecting a specific card during selection process"""
	if not game.selection_manager.is_selecting():
		print("❌ No selection process active")
		return false
	
	# Simulate clicking the target card
	game.selection_manager.handle_card_click(target_card)
	
	# Wait a frame for the selection to process
	await get_tree().process_frame
	
	# Check if selection is complete and validate
	var current_selection = game.selection_manager.current_selection
	if current_selection and current_selection.is_complete:
		game.selection_manager._on_validate_pressed()
		print("✅ Selection completed with: ", target_card.cardData.cardName)
		return true
	else:
		print("❌ Selection not complete after clicking card")
		return false

func waitForSelectionStart(max_frames: int = 10) -> bool:
	"""Wait for selection to start (useful for async operations)"""
	for i in range(max_frames):
		if game.selection_manager.is_selecting():
			print("✅ Selection started after ", i+1, " frames")
			return true
		await get_tree().process_frame
	
	print("❌ Selection didn't start within ", max_frames, " frames")
	return false

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
		"graveyard":
			actual = game.get_cards_in_player_graveyard().size()
		_:
			return assert_test(false, "Unknown zone: " + zone)
	
	return assert_test_equal(actual, expected, "Expected %d cards in %s, but found %d" % [expected, zone, actual])

func assertCardExists(card_name: String, zone: String = "play") -> bool:
	"""Assert that a specific card exists in a zone"""
	var found = false
	match zone:
		"play":
			for card in getCardsInPlay():
				if card.cardData.cardName.to_lower() == card_name.to_lower():
					found = true
					break
		"hand":
			for card in game.player_hand.get_children():
				if card is Card and card.cardData.cardName.to_lower() == card_name.to_lower():
					found = true
					break
		"graveyard":
			var graveyard_cards = game.get_cards_in_player_graveyard()
			for card_data in graveyard_cards:
				if card_data.cardName.to_lower() == card_name.to_lower():
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
	var card = createCardFromName("goblin pair")
	if not assert_test_not_null(card, "Card should be created"):
		return false
	if not assert_test_equal(card.cardData.cardName, "Goblin pair", "Card should have correct name"):
		return false
	return true

func test_card_play_basic():
	"""Test basic card playing functionality"""
	var card = createCardFromName("goblin pair")
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
	var card = createCardFromName("goblin pair")  # costs 1
	addCardToHand(card)
	setPlayerGold(0)  # Not enough to pay 1 gold cost
	
	# Verify gold is actually 0 before attempting to play
	var gold_before = game.game_data.player_gold.getValue()
	print("🪙 Gold before tryPlayCard: ", gold_before)
	if not assert_test_equal(gold_before, 0, "Gold should be 0 before play attempt"):
		return false
	
	await game.tryPlayCard(card, game.player_base)
	
	# Card should still be in hand (payment should have failed)
	if not assertCardCount(0, "play"):
		return false
	if not assertCardCount(1, "hand"):
		return false
	
	# Verify gold is still 0 (no payment occurred)
	var gold_after = game.game_data.player_gold.getValue()
	if not assert_test_equal(gold_after, 0, "Gold should still be 0 after failed payment"):
		return false
	
func test_animation_completion():
	"""Test that card animations complete properly"""
	var card = createCardFromName("goblin pair")
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
	var c = createCardFromName("goblin pair")
	addCardToHand(c)
	game.game_data.player_gold.setValue(99)
	await game.tryPlayCard(c, game.player_base)
	var cardsInPlay = game.player_base.getCards()
	if not assert_test_equal(cardsInPlay.size(), 2, "Goblin Pair should spawn 2 cards"):
		return false

func test_card_creation_isolated_scripts():
	var gob1 = CardLoaderAL.getCardByName("Goblin Kid")
	var gob2 = CardLoaderAL.getCardByName("Goblin Kid")
	gob1.cardName = "ChangedName"
	gob1.isTapped = true
	if not assert_test_true(gob2.cardName == "Goblin Kid", "Name isolation issue"):
		return false
		
	if not assert_test_true(gob2.isTapped == false, "Value isolation issue"):
		return false
	return true
		
func test_goblin_boss_extra_deck_casting():
	"""Test playing Goblin Boss from extra deck with proper selection"""
	# Setup: Give player plenty of gold
	setPlayerGold(99)
	
	# Step 1: Play 2 Goblin Pairs to get 4 goblins total (2 pairs + 2 tokens)
	addCardToExtraDeck(CardLoaderAL.getCardByName("Goblin Boss"))
	var goblin_pair_1 = createCardFromName("goblin pair")
	addCardToHand(goblin_pair_1)
	
	# Play first Goblin Pair and wait for animation to complete
	await game.tryPlayCard(goblin_pair_1, game.player_base)
	if not assertCardCount(2, "play"):  # Should have 2 goblins now
		return false
	
	# Step 2: Trigger extra deck view to show available cards
	game._toggleExtraDeckView()
	await get_tree().process_frame  # Wait for extra hand to be populated
	
	# Step 3: Assert that Goblin Boss appears in extra hand display
	var extra_hand_cards = game.extra_hand.get_children().filter(func(child): return child is Card)
	var goblin_boss_found = false
	var goblin_boss_card: Card = null
	
	for card in extra_hand_cards:
		if card.cardData.cardName == "Goblin Boss":
			goblin_boss_found = true
			goblin_boss_card = card
			break
	
	if not assert_test_true(goblin_boss_found, "Goblin Boss should be displayed in extra hand when 2+ goblins are in play"):
		return false
	
	# Step 4: Attempt to play Goblin Boss from extra deck
	# This should trigger selection for the additional cost (sacrifice 2 goblins)
	var goblins_before = getCardsInPlay().filter(func(card:Card): return card.cardData.hasSubtype("Goblin")).size()
	if not assert_test(goblins_before >= 2, "Should have at least 2 goblins before casting boss"):
		return false
	
	# Get the first 2 goblin cards for selection
	var goblins_in_play = getCardsInPlay().filter(func(card): return card.cardData.hasSubtype("Goblin"))
	if not assert_test(goblins_in_play.size() >= 2, "Should have at least 2 goblins to sacrifice"):
		return false
	
	# Prepare selection data with the two goblins to sacrifice
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_sacrifice_target(goblins_in_play[0])
	selections.add_sacrifice_target(goblins_in_play[1])
	
	await game.tryPlayCard(goblin_boss_card, game.player_base, selections)
	
	# Step 5: Assert final state
	var final_cards = getCardsInPlay()
	var boss_found = final_cards.filter(func(c: Card): return c.cardData.cardName == "Goblin Boss").size() >= 1
	
	if not assert_test_true(boss_found, "Goblin Boss should be in play"):
		return false
	if not assert_test_equal(final_cards.size(), 1, "Should have exactly 1 card in play: Goblin Boss"):
		return false

func test_combat_zone_button_click():
	"""Test clicking combat zone resolve button changes zone resolution state"""
	# Setup: Create a creature and place it in a combat zone
	var card = createCardFromName("goblin pair")
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
	var goblin1 = createCardFromName("goblin")
	var goblin2 = createCardFromName("goblin")
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

func test_bolt_spell_with_valid_target():
	"""Test casting Bolt spell with a legal target - bolt and target should end up in graveyard"""
	# Setup: Create Bolt spell and a target creature
	var bolt_card = createCardFromName("Bolt")
	var target_creature = createCardFromName("goblin")
	
	addCardToHand(bolt_card)
	addCardToHand(target_creature)
	setPlayerGold(99)
	
	# Play the target creature first
	await game.tryPlayCard(target_creature, game.player_base)
	if not assertCardExists("goblin", "play"):
		return false
	if not assertCardCount(1, "play"):
		return false
	
	# Prepare selection data with the target creature
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	
	# Cast Bolt targeting the creature
	await game.tryPlayCard(bolt_card, game.player_base, selections)
	
	# Verify final state: both bolt and target should be in graveyard
	if not assertCardExists("Bolt", "graveyard"):
		return false
	if not assertCardExists("Goblin", "graveyard"):
		return false
	if not assertCardCount(0, "play"):  # No creatures left in play
		return false
	if not assertCardCount(0, "hand"):  # No cards left in hand
		return false

func test_bolt_spell_cancelled_with_target():
	"""Test casting Bolt with target selected but then cancelled - spell should return to hand, creature should stay in play"""
	# Setup: Create Bolt spell and a target creature
	var bolt_card = createCardFromName("Bolt")
	var target_creature = createCardFromName("goblin")
	
	addCardToHand(bolt_card)
	addCardToHand(target_creature)
	setPlayerGold(99)
	
	# Play the target creature first
	await game.tryPlayCard(target_creature, game.player_base)
	if not assertCardExists("Goblin", "play"):
		return false
	if not assertCardCount(1, "play"):
		return false
	
	# Prepare selection data showing cancellation
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	selections.cancelled = true
	
	# Store the card before attempting to play it
	var initial_hand_cards = game.player_hand.get_children().filter(func(c): return c is Card)
	var bolt_in_hand = null
	for card in initial_hand_cards:
		if card.cardData.cardName == "Bolt":
			bolt_in_hand = card
			break
	
	if not assert_test_not_null(bolt_in_hand, "Bolt should be in hand before casting"):
		return false
	
	# Attempt to cast Bolt but cancel
	await game.tryPlayCard(bolt_in_hand, game.player_base, selections)
	
	# Wait a frame for any reparenting to complete
	await get_tree().process_frame
	
	# Check what cards are actually in hand
	for i in range(game.player_hand.get_child_count()):
		var card = game.player_hand.get_child(i)
		if card is Card:
			print("  - ", card.cardData.cardName)
	
	# Verify final state: bolt should be back in hand, creature should still be in play
	if not assertCardExists("Bolt", "hand"):
		return false
	if not assertCardExists("Goblin", "play"):
		return false
	if not assertCardCount(1, "play"):  # Creature still in play
		return false
	if not assertCardCount(1, "hand"):  # Bolt back in hand
		return false
	if not assertCardCount(0, "graveyard"):  # Nothing in graveyard
		return false
	
	return true

func test_bolt_spell_empty_board():
	"""Test casting Bolt on empty board - spell should be returned to hand"""
	# Setup: Create Bolt spell only, no target creatures
	var bolt_card = createCardFromName("Bolt")
	addCardToHand(bolt_card)
	setPlayerGold(99)
	
	# Verify board is empty
	if not assertCardCount(0, "play"):
		return false
	if not assertCardCount(1, "hand"):
		return false
	
	# Attempt to cast Bolt with no targets available
	await game.tryPlayCard(bolt_card, game.player_base)
	
	# Verify final state: bolt should be back in hand since no valid targets
	if not assertCardExists("Bolt", "hand"):
		return false
	if not assertCardCount(0, "play"):  # Board still empty
		return false
	if not assertCardCount(1, "hand"):  # Bolt back in hand
		return false
	if not assertCardCount(0, "graveyard"):  # Nothing in graveyard
		return false

func test_deck_card_player_control():
	"""Test that cards drawn from deck have correct player control"""
	# Add a card to player deck
	var test_card_data = CardLoaderAL.getCardByName("Goblin")
	addCardToDeck(test_card_data, true)  # Add to player deck
	
	# Get initial hand count
	var initial_hand_count = game.player_hand.get_child_count()
	
	# Draw one card from player deck
	await game.drawCard(1, true)
	
	# Verify hand increased by one
	if not assertCardCount(initial_hand_count + 1, "hand"):
		return false
	
	# Get the newly drawn card (last child in hand)
	var drawn_card = game.player_hand.get_children()[-1] as Card
	if not assert_test_not_null(drawn_card, "Should have drawn a card"):
		return false
	
	# Verify the card is player controlled
	if not assert_test_true(drawn_card.cardData.playerControlled, "Drawn card should be player controlled"):
		return false
	
	# Verify the card is player owned
	if not assert_test_true(drawn_card.cardData.playerOwned, "Drawn card should be player owned"):
		return false
	
	return true

func test_deck_card_opponent_control():
	"""Test that cards drawn from opponent deck have correct opponent control"""
	# Add a card to opponent deck
	var test_card_data = CardLoaderAL.getCardByName("Goblin")
	addCardToDeck(test_card_data, false)  # Add to opponent deck
	
	# Get initial opponent hand count
	var initial_hand_count = game.opponent_hand.get_child_count()
	
	# Draw one card from opponent deck
	await game.drawCard(1, false)
	
	# Verify opponent hand increased by one
	var actual_hand_count = game.opponent_hand.get_child_count()
	if not assert_test_equal(actual_hand_count, initial_hand_count + 1, "Opponent hand should increase by one"):
		return false
	
	# Get the newly drawn card (last child in opponent hand)
	var drawn_card = game.opponent_hand.get_children()[-1] as Card
	if not assert_test_not_null(drawn_card, "Should have drawn a card to opponent hand"):
		return false
	
	# Verify the card is NOT player controlled
	if not assert_test_false(drawn_card.cardData.playerControlled, "Drawn card should NOT be player controlled"):
		return false
	
	# Verify the card is NOT player owned
	if not assert_test_false(drawn_card.cardData.playerOwned, "Drawn card should NOT be player owned"):
		return false
	
	return true

func test_player_card_payment():
	"""Test that player controlled cards use player gold for payment"""
	# Add a card to player deck and draw it
	var test_card_data = CardLoaderAL.getCardByName("Goblin Pair")  # Costs 1 gold
	addCardToDeck(test_card_data, true)
	
	# Set initial gold
	setPlayerGold(3)
	var initial_gold = game.game_data.player_gold.getValue()
	
	# Draw the card
	await game.drawCard(1, true)
	
	# Get the drawn card
	var drawn_card = game.player_hand.get_children()[-1] as Card
	if not assert_test_not_null(drawn_card, "Should have drawn a card"):
		return false
	
	# Verify the card is player controlled before playing
	if not assert_test_true(drawn_card.cardData.playerControlled, "Drawn card should be player controlled"):
		return false
	
	# Play the card
	await game.tryPlayCard(drawn_card, game.player_base)
	
	# Verify gold was deducted from player gold
	var final_gold = game.game_data.player_gold.getValue()
	var expected_gold = initial_gold - drawn_card.cardData.goldCost
	if not assert_test_equal(final_gold, expected_gold, "Player gold should decrease by card cost"):
		return false
	
	return true

func test_deck_draw_order():
	"""Test that cards are drawn from the top of the deck (index 0) in correct order"""
	# Clear deck first to ensure clean test
	game.deck.cards.clear()
	game.deck.update_size()
	
	# Add three different cards to deck in specific order
	var card1_data = CardLoaderAL.getCardByName("Goblin")
	var card2_data = CardLoaderAL.getCardByName("Goblin Pair") 
	var card3_data = CardLoaderAL.getCardByName("Bolt")
	
	# Add cards to deck using helper method - card1 should be at index 0 (top), card3 at index 2 (bottom)
	addCardToDeck(card1_data, true)  # Index 0 - should be drawn first
	addCardToDeck(card2_data, true)  # Index 1 - should be drawn second
	addCardToDeck(card3_data, true)  # Index 2 - should be drawn third
	
	# Verify deck has 3 cards
	if not assert_test_equal(game.deck.get_card_count(), 3, "Deck should have 3 cards"):
		return false
	
	# Verify the top card (index 0) is Goblin
	if not assert_test_equal(game.deck.cards[0].cardName, "goblin", "Top card should be Goblin"):
		return false
	
	# Draw one card
	var initial_hand_count = game.player_hand.get_child_count()
	await game.drawCard(1, true)
	
	# Verify hand increased by one
	if not assert_test_equal(game.player_hand.get_child_count(), initial_hand_count + 1, "Hand should increase by 1"):
		return false
	
	# Get the drawn card (last child in hand)
	var drawn_card = game.player_hand.get_children()[-1] as Card
	if not assert_test_not_null(drawn_card, "Should have drawn a card"):
		return false
		
	if !drawn_card.cardData.playerControlled:
		print("Card should be player controlled")
		return false
	
	# Verify the drawn card is the Goblin (was at index 0)
	if not assert_test_equal(drawn_card.cardData.cardName, "goblin", "Drawn card should be Goblin (from top of deck)"):
		return false
	
	# Verify the new top card (index 0) is now Goblin Pair (was index 1)
	if not assert_test_equal(game.deck.cards[0].cardName, "Goblin pair", "New top card should be Goblin Pair"):
		return false
	
	# Verify the remaining bottom card (index 1) is Bolt (was index 2)
	if not assert_test_equal(game.deck.cards[1].cardName, "Bolt", "Bottom card should be Bolt"):
		return false
	
	return true

func test_replace_mechanism() -> bool:
	"""Test Replace keyword parsing and cost calculation"""
	print("=== Testing Replace Mechanism ===")
	
	# Create a mock Punglynd Drengr card with Replace
	var drengr_card = createCardFromName("Punglynd Drengr", true)
	
	# Verify Replace was parsed correctly
	if not assert_test(drengr_card.cardData.additionalCosts.size() > 0, "Drengr should have additional costs"):
		return false
	
	var replace_cost = null
	for cost in drengr_card.cardData.additionalCosts:
		if cost.get("cost_type") == "Replace":
			replace_cost = cost
			break
	
	if not assert_test(replace_cost != null, "Should find Replace cost data"):
		return false
	
	if not assert_test(replace_cost.get("valid_card") == "Card.YouCtrl+Cost.1+Creature", "Should parse ValidCard$ correctly"):
		return false
	
	if not assert_test(replace_cost.get("valid_card_alt") == "Card.YouCtrl+Cost.1+Grown-up", "Should parse ValidCardAlt$ correctly"):
		return false
	
	if not assert_test(replace_cost.get("add_reduction") == 2, "Should parse AddReduction correctly"):
		return false
	
	# Test hasReplaceOption when no valid targets
	if not assert_test(not CardPaymentManagerAL.hasReplaceOption(drengr_card), "Should not have Replace option with no valid targets"):
		return false
	
	# Create a valid target (1-cost creature)
	var target_creature = createCardFromName("Punglynd Child", true)
	if not assert_test_not_null(target_creature, "Should be able to create Punglynd Child card"):
		return false
	GameUtility.reparentWithoutMoving(target_creature, game.player_base)
	# Wait a frame for the card to be properly added
	await get_tree().process_frame
	
	# Now Replace should be available
	if not assert_test(CardPaymentManagerAL.hasReplaceOption(drengr_card), "Should have Replace option with valid targets"):
		return false
	
	# Test cost calculation with regular creature
	var replace_cost_regular = CardPaymentManagerAL.calculateReplaceCost(drengr_card, target_creature)
	if not assert_test_equal(replace_cost_regular, 2, "Replace cost with regular creature should be 3-1=2"):
		return false
	
	# Test getValidReplaceTargets
	var valid_targets = CardPaymentManagerAL.getValidReplaceTargets(drengr_card, replace_cost)
	if not assert_test(valid_targets.size() >= 1, "Should find at least one valid target"):
		return false
	
	print("✅ Replace mechanism test passed!")
	return true

func test_replace_with_additional_reduction() -> bool:
	"""Test Replace mechanism with additional cost reduction for Grown-up targets"""
	print("=== Testing Replace with Additional Reduction ===")
	
	# Create a mock Punglynd Drengr card with Replace
	var drengr_card = createCardFromName("Punglynd Drengr", true)
	
	# Get Replace cost data
	var replace_cost = null
	for cost in drengr_card.cardData.additionalCosts:
		if cost.get("cost_type") == "Replace":
			replace_cost = cost
			break
	
	if not assert_test(replace_cost != null, "Should find Replace cost data"):
		return false
	
	# Create a Grown-up target for extra reduction
	var grownup_target = createCardFromName("Punglynd Child", true)
	grownup_target.cardData.subtypes.append("Grown-up")
	GameUtility.reparentWithoutMoving(grownup_target, game.player_base)
	await get_tree().process_frame
	
	# Test cost calculation with Grown-up (should get additional reduction)
	var replace_cost_grownup = CardPaymentManagerAL.calculateReplaceCost(drengr_card, grownup_target)
	if not assert_test_equal(replace_cost_grownup, 0, "Replace cost with Grown-up should be 3-1-2=0"):
		return false
	
	# Test that getValidReplaceTargets finds the Grown-up target
	var valid_targets = CardPaymentManagerAL.getValidReplaceTargets(drengr_card, replace_cost)
	var found_grownup = false
	for target in valid_targets:
		if "Grown-up" in target.cardData.subtypes:
			found_grownup = true
			break
	
	if not assert_test(found_grownup, "Should find Grown-up target in valid targets"):
		return false
	
	print("✅ Replace with additional reduction test passed!")
	return true

func test_activated_ability_parsing() -> bool:
	"""Test parsing of activated abilities (AA:$)"""
	print("=== Testing Activated Ability Parsing ===")
	
	# Test with Punglynd Hersir's activated ability
	var hersir_card = createCardFromName("Punglynd Hersir", true)
	
	if not assert_test_not_null(hersir_card, "Should create Punglynd Hersir card"):
		return false
		
	if not assert_test_not_null(hersir_card.cardData, "Card should have cardData"):
		return false
	
	# Check that the card has abilities
	if not assert_test(hersir_card.cardData.get_all_abilities().size() > 0, "Hersir should have abilities"):
		return false
	
	# Look for the activated ability
	var activated_ability = null
	for ability in hersir_card.cardData.activated_abilities:
		activated_ability = ability
		break
	
	if not assert_test_not_null(activated_ability, "Should find activated ability"):
		return false
	
	# Test the parsed activated ability structure
	# Note: PumpAll is mapped to ADD_KEYWORD effect type
	if not assert_test_equal(activated_ability.effect_type, EffectType.Type.ADD_KEYWORD, "Effect type should be ADD_KEYWORD (PumpAll)"):
		return false
	
	# Test activation costs parsing
	var costs = activated_ability.activation_costs
	if not assert_test_equal(costs.size(), 2, "Should have 2 activation costs"):
		return false
	
	# Check sacrifice cost
	var sac_cost = null
	var pay_cost = null
	for cost in costs:
		if cost.get("type") == "Sacrifice":
			sac_cost = cost
		elif cost.get("type") == "PayMana":
			pay_cost = cost
	
	if not assert_test_not_null(sac_cost, "Should have sacrifice cost"):
		return false
	if not assert_test_equal(sac_cost.get("target"), "Self", "Sacrifice target should be Self"):
		return false
	
	if not assert_test_not_null(pay_cost, "Should have mana payment cost"):
		return false
	if not assert_test_equal(pay_cost.get("amount"), 1, "Pay cost should be 1"):
		return false
	
	# Test target conditions
	var target_conditions = activated_ability.targeting_requirements
	if not assert_test_equal(target_conditions.get("ValidCards"), "Creature.YouCtrl", "Valid cards should be Creature.YouCtrl"):
		return false
	
	# Test effect parameters
	var effect_params = activated_ability.effect_parameters
	if not assert_test_equal(effect_params.get("KW"), "Spellshield", "Keyword should be Spellshield"):
		return false
	if not assert_test_equal(effect_params.get("Duration"), "EndOfTurn", "Duration should be EndOfTurn"):
		return false
	
	print("✅ Activated ability parsing test passed!")
	return true

func test_tap_system() -> bool:
	"""Test the tap/untap system for cards"""
	print("=== Testing Tap System ===")
	
	# Create a test creature (try Tap Test Creature first, fallback to any creature)
	var test_card = createCardFromName("Tap Test Creature", true)
	if not test_card:
		# Fallback to any available creature for basic tap testing
		test_card = createCardFromName("Punglynd Hersir", true)
	if not assert_test_not_null(test_card, "Should create test card"):
		return false
	
	# Add it to player base
	GameUtility.reparentWithoutMoving(test_card, game.player_base)
	test_card.setFlip(true)
	test_card.getAnimator().make_small()
	
	# Test 1: Card should start untapped
	if not assert_test_false(test_card.cardData.is_tapped(), "Card should start untapped"):
		return false
	if not assert_test_true(test_card.cardData.can_tap(), "Card should be able to tap initially"):
		return false
	
	# Test 2: Test tapping manually
	test_card.cardData.tap()
	if not assert_test_true(test_card.cardData.is_tapped(), "Card should be tapped after tap()"):
		return false
	if not assert_test_false(test_card.cardData.can_tap(), "Card should not be able to tap when already tapped"):
		return false
	
	# Test 3: Test untapping
	test_card.cardData.untap()
	if not assert_test_false(test_card.cardData.is_tapped(), "Card should be untapped after untap()"):
		return false
	if not assert_test_true(test_card.cardData.can_tap(), "Card should be able to tap after untapping"):
		return false
	
	# Test 4: Test movement tapping (assuming we can move to combat)
	if game.combatZones.size() > 0:
		var combat_zone = game.combatZones[0] as CombatZone
		var empty_spot = combat_zone.getFirstEmptyLocation(true)
		
		if empty_spot:
			# Try to move card to combat (should tap it)
			var move_successful = game.moveCardToCombatZone(test_card, empty_spot)
			if assert_test_true(move_successful, "Movement to combat should succeed"):
				if not assert_test_true(test_card.cardData.is_tapped(), "Card should be tapped after moving to combat"):
					return false
				
				# Try to move again (should fail because card is tapped)
				var second_move = game.moveCardToCombatZone(test_card, empty_spot)
				if not assert_test_false(second_move, "Second movement should fail (card is tapped)"):
					return false
	
	# Test 5: Test activated ability with tap cost
	# First untap the card
	test_card.cardData.untap()
	setPlayerGold(10)  # Give plenty of mana
	
	# Find activated abilities with tap cost
	var tap_abilities = []
	for ability in test_card.cardData.activated_abilities:
		var costs = ability.activation_costs
		for cost in costs:
			if cost.get("type") == "Tap":
				tap_abilities.append(ability)
				break
	
	if tap_abilities.size() > 0:
		var ability = tap_abilities[0]
		
		# Check if we can pay costs (should be true)
		if assert_test_true(CardPaymentManagerAL.canPayCosts(ability.activation_costs, test_card), "Should be able to pay tap costs when untapped"):
			# Activate the ability
			await AbilityManagerAL.activateAbility(test_card, ability, game)
			
			# Check that card is now tapped
			if not assert_test_true(test_card.cardData.is_tapped(), "Card should be tapped after using tap ability"):
				return false
			
			# Try to use ability again (should fail)
			if not assert_test_false(CardPaymentManagerAL.canPayCosts(ability.activation_costs, test_card), "Should not be able to pay tap costs when already tapped"):
				return false
	
	print("✅ Tap system test passed!")
	return true

func test_temporary_keyword_effects() -> bool:
	"""Test that keywords granted until end of turn are properly removed"""
	print("=== Testing Temporary Keyword Effects ===")
	
	# Step 1: Create test creatures - one with activated ability, targets for the effect
	var hersir_card = createCardFromName("Punglynd Hersir", true)
	if not assert_test_not_null(hersir_card, "Should create Punglynd Hersir"):
		return false
	
	var target_card = createCardFromName("Goblin", true)
	if not assert_test_not_null(target_card, "Should create target creature"):
		return false
	
	# Step 2: Place both cards in play
	GameUtility.reparentWithoutMoving(hersir_card, game.player_base)
	hersir_card.setFlip(true)
	hersir_card.getAnimator().make_small()
	
	GameUtility.reparentWithoutMoving(target_card, game.player_base)
	target_card.setFlip(true)
	target_card.getAnimator().make_small()
	
	await get_tree().process_frame
	
	# Step 3: Verify target doesn't have Spellshield initially
	var initial_abilities = target_card.cardData.get_all_abilities().size()
	var has_spellshield_initial = false
	for ability in target_card.cardData.get_all_abilities():
		if ability.effect_parameters.get("KW") == "Spellshield":
			has_spellshield_initial = true
			break
	
	if not assert_test_false(has_spellshield_initial, "Target should not have Spellshield initially"):
		return false
	
	# Step 4: Set up resources and activate Hersir's ability
	setPlayerGold(10)  # Plenty of mana
	
	# Find the activated ability
	var activated_ability = null
	for ability in hersir_card.cardData.activated_abilities:
		activated_ability = ability
		break
	
	if not assert_test_not_null(activated_ability, "Hersir should have activated ability"):
		return false
	
	# Step 5: Activate the ability (sacrifices Hersir, grants Spellshield to all creatures)
	print("🎯 Activating Hersir's ability to grant Spellshield...")
	await AbilityManagerAL.activateAbility(hersir_card, activated_ability, game)
	await get_tree().process_frame
	
	# Step 6: Verify target now has Spellshield
	var has_spellshield_after = false
	for ability in target_card.cardData.get_all_abilities():
		if ability.effect_parameters.get("KW") == "Spellshield":
			has_spellshield_after = true
			break
	
	if not assert_test_true(has_spellshield_after, "Target should have Spellshield after activation"):
		return false
	
	var abilities_after_grant = target_card.cardData.abilities.size()
	if not assert_test_equal(abilities_after_grant, initial_abilities + 1, "Should have one more ability after granting Spellshield"):
		return false
	
	# Step 7: Verify the effect is tracked on the card itself
	if not assert_test_true(target_card.cardData.has_temporary_effects(), "Target card should have temporary effects tracked"):
		return false
	
	if not assert_test_true(target_card.cardData.has_temporary_effect(EffectType.Type.ADD_KEYWORD), "Target card should have ADD_KEYWORD temporary effect"):
		return false
	
	var card_temp_effects = target_card.cardData.get_temporary_effects_by_duration("EndOfTurn")
	if not assert_test_equal(card_temp_effects.size(), 1, "Should have 1 end-of-turn effect on card"):
		return false
	
	print("  ℹ️ ", target_card.cardData.temporary_effects.size(), " temporary effect(s) tracked on card")
	
	# Step 8: Trigger end of turn to clean up temporary effects
	print("🔄 Starting new turn to trigger cleanup...")
	await game.onTurnStart()
	await get_tree().process_frame
	
	# Step 9: Verify Spellshield was removed
	var has_spellshield_after_turn = false
	for ability in target_card.cardData.get_all_abilities():
		if ability.effect_parameters.get("KW") == "Spellshield":
			has_spellshield_after_turn = true
			break
	
	if not assert_test_false(has_spellshield_after_turn, "Target should not have Spellshield after end of turn"):
		return false
	
	var abilities_after_cleanup = target_card.cardData.abilities.size()
	if not assert_test_equal(abilities_after_cleanup, initial_abilities, "Should have original number of abilities after cleanup"):
		return false
	
	# Step 10: Verify the effect was removed from the card's tracking
	if not assert_test_false(target_card.cardData.has_temporary_effects(), "Target card should have no temporary effects after cleanup"):
		return false
	
	if not assert_test_false(target_card.cardData.has_temporary_effect(EffectType.Type.ADD_KEYWORD), "Target card should not have ADD_KEYWORD temporary effect after cleanup"):
		return false
	
	print("✅ Temporary keyword effects test passed!")
	return true

func test_growth_spell_pump() -> bool:
	"""Test Growth spell - pump effect that gives +3 power until end of turn"""
	print("=== Testing Growth Spell (Pump Effect) ===")
	
	# Step 1: Create Growth spell and a target creature
	var growth_card = createCardFromName("Growth", true)
	if not assert_test_not_null(growth_card, "Should create Growth spell"):
		return false
	
	var target_creature = createCardFromName("Goblin", true)
	if not assert_test_not_null(target_creature, "Should create target creature"):
		return false
	
	# Step 2: Place target in play and spell in hand
	GameUtility.reparentWithoutMoving(target_creature, game.player_base)
	target_creature.setFlip(true)
	target_creature.getAnimator().make_small()
	
	addCardToHand(growth_card)
	setPlayerGold(10)
	
	await get_tree().process_frame
	
	# Step 3: Record initial power
	var initial_power = target_creature.cardData.power
	print("  Initial power: ", initial_power)
	
	# Step 4: Cast Growth targeting the creature
	print("🎯 Casting Growth on ", target_creature.cardData.cardName)
	
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	
	await game.tryPlayCard(growth_card, game.player_base, selections)
	await get_tree().process_frame
	
	# Step 5: Verify power was increased by 3
	var boosted_power = target_creature.cardData.power
	if not assert_test_equal(boosted_power, initial_power + 3, "Power should be increased by 3"):
		return false
	
	print("  Boosted power: ", boosted_power)
	
	# Step 6: Verify temporary effect is tracked
	if not assert_test_true(target_creature.cardData.has_temporary_effects(), "Should have temporary effect"):
		return false
	
	if not assert_test_true(target_creature.cardData.has_temporary_effect(EffectType.Type.PUMP), "Should have temporary PUMP effect"):
		return false
	
	var temp_effects = target_creature.cardData.get_temporary_effects_by_duration("EndOfTurn")
	if not assert_test_equal(temp_effects.size(), 1, "Should have 1 end-of-turn effect"):
		return false
	
	# Step 7: Verify Growth spell went to graveyard
	if not assertCardExists("Growth", "graveyard"):
		return false
	
	# Step 8: End turn to trigger cleanup
	print("🔄 Ending turn to test power boost removal...")
	await game.onTurnStart()
	await get_tree().process_frame
	
	# Step 9: Verify power returned to original value
	var final_power = target_creature.cardData.power
	if not assert_test_equal(final_power, initial_power, "Power should return to original after end of turn"):
		return false
	
	print("  Final power after cleanup: ", final_power)
	
	# Step 10: Verify temporary effect was removed
	if not assert_test_false(target_creature.cardData.has_temporary_effects(), "Should have no temporary effects after cleanup"):
		return false
	
	if not assert_test_false(target_creature.cardData.has_temporary_effect(EffectType.Type.PUMP), "Should have no PUMP effect after cleanup"):
		return false
	
	print("✅ Growth spell pump effect test passed!")
	return true

func test_punglynd_child_growup():
	"""Test that Punglynd Child gains 'Grown-up' subtype after attacking and passing turn"""
	print("🧪 Testing Punglynd Child grow-up ability...")
	
	# Step 1: Create Punglynd Child token
	var child_card = createCardFromName("Punglynd Child", true)
	if not assert_test_not_null(child_card, "Should be able to create Punglynd Child card"):
		return false
	
	# Step 2: Place card directly in player base (battlefield)
	game.player_base.add_child(child_card)
	
	# Step 3: Verify initial state - should not have Grown-up subtype yet
	if not assert_test_false("Grown-up" in child_card.cardData.subtypes, "Child should not have Grown-up subtype initially"):
		return false
	
	# Also verify the initial type line display
	var initial_type_line = child_card.card_2d.type_label.text
	if not assert_test_false(initial_type_line.contains("Grown-up"), "Type line should not show 'Grown-up' initially"):
		return false
	
	# Step 4: Make the child attack by moving it to a combat zone
	var combat_zone = game.combatZones[0] as CombatZone
	var attack_spot = combat_zone.getFirstEmptyLocation(true)
	if not assert_test_not_null(attack_spot, "Should have an empty combat spot"):
		return false
	
	# Move to combat zone (this triggers attack and marks hasAttackedThisTurn)
	await game.executeCardAttacks(child_card, attack_spot)
	
	# Step 5: Verify the card attacked this turn
	if not assert_test_true(child_card.cardData.hasAttackedThisTurn, "Child should be marked as having attacked this turn"):
		return false
	
	# Step 6: Start new turn to trigger end-of-turn phase (simulates real game flow)
	await game.onTurnStart()
	
	# Step 7: Verify the child now has the Grown-up subtype
	if not assert_test_true("Grown-up" in child_card.cardData.subtypes, "Child should have Grown-up subtype after attacking and end-of-turn trigger"):
		return false
	
	# Step 8: Verify the type line display is updated
	var updated_type_line = child_card.card_2d.type_label.text
	if not assert_test_true(updated_type_line.contains("Grown-up"), "Type line should show 'Grown-up' after trigger"):
		return false
	
	# Verify the full type string is correct
	var expected_type_string = child_card.cardData.getFullTypeString()
	if not assert_test_equal(updated_type_line, expected_type_string, "Type line should match CardData.getFullTypeString()"):
		return false
	
	print("✅ Punglynd Child grow-up test passed!")
	return true

func test_replace_with_insufficient_gold() -> bool:
	"""Test that Replace mechanism allows playing cards when player has insufficient gold but valid targets"""
	print("=== Testing Replace with Insufficient Gold ===")
	
	# Step 1: Set player gold to 0
	setPlayerGold(0)
	if not assert_test_equal(game.game_data.player_gold.getValue(), 0, "Player should have 0 gold"):
		return false
	
	# Step 2: Create a Punglynd Child token in player base
	var child_card = createCardFromName("Punglynd Child", true)
	if not assert_test_not_null(child_card, "Should be able to create Punglynd Child card"):
		return false
	
	# Add Grown-up subtype to the child to match ValidCardAlt$ filter
	child_card.cardData.subtypes.append("Grown-up")
	
	# Place the child in player base
	GameUtility.reparentWithoutMoving(child_card, game.player_base)
	await get_tree().process_frame
	
	if not assert_test_true(child_card.cardData.subtypes.has("Grown-up"), "Child should have Grown-up subtype"):
		return false
	
	# Step 3: Create Punglynd Childbearer and add to hand
	var childbearer_card = createCardFromName("Punglynd Childbearer", true)
	if not assert_test_not_null(childbearer_card, "Should be able to create Punglynd Childbearer"):
		return false
	
	GameUtility.reparentWithoutMoving(childbearer_card, game.player_hand)
	await get_tree().process_frame
	
	# Step 4: Verify the card has Replace option available
	if not assert_test_true(CardPaymentManagerAL.hasReplaceOption(childbearer_card), "Childbearer should have Replace option with valid targets"):
		return false
	
	# Step 5: Calculate expected Replace cost (3 - 1 - 2 = 0 for Grown-up)
	var replace_cost = CardPaymentManagerAL.calculateReplaceCost(childbearer_card, child_card)
	if not assert_test_equal(replace_cost, 0, "Replace cost with Grown-up should be 3-1-2=0"):
		return false
	
	# Step 6: Verify the card is castable (should be true even with 0 gold due to Replace)
	if not assert_test_true(CardPaymentManagerAL.isCardCastable(childbearer_card), "Childbearer should be castable with Replace"):
		return false
	
	# Step 7: Store initial counts
	var initial_hand_count = game.player_hand.get_children().size()
	var initial_base_count = game.player_base.getCards().size()
	
	# Step 8: Use pre-selection system to specify Replace target
	print("🎮 Starting card play with Replace mechanism using pre-selection...")
	
	var selections = SelectionManager.CardPlaySelections.new()
	selections.set_replace_target(child_card)
	
	# Step 9: Try to play the card using Replace with pre-selections
	await game.tryPlayCard(childbearer_card, game.player_base, selections)
	print("✅ Card play with Replace completed")
	await get_tree().process_frame
	var final_hand_count = game.player_hand.get_children().size()
	var final_base_count = game.player_base.getCards().size()
	
	if not assert_test_equal(final_hand_count, initial_hand_count - 1, "Hand count should decrease by 1"):
		return false
	
	if not assert_test_equal(final_base_count, initial_base_count, "Base count should stay the same (child replaced by childbearer)"):
		return false
	
	# Step 10: Verify the Childbearer is now in play
	var cards_in_base = game.player_base.getCards()
	var childbearer_in_play = false
	for card in cards_in_base:
		if card.cardData.cardName == "Punglynd Childbearer":
			childbearer_in_play = true
			break
	
	if not assert_test_true(childbearer_in_play, "Punglynd Childbearer should be in play"):
		return false
	
	# Step 11: Verify player still has 0 gold (Replace cost was 0)
	if not assert_test_equal(game.game_data.player_gold.getValue(), 0, "Player should still have 0 gold after Replace"):
		return false
	
	# Step 12: Verify the original child is no longer in play (was replaced)
	var child_still_in_play = false
	for card in cards_in_base:
		if card == child_card:
			child_still_in_play = true
			break
	
	if not assert_test_false(child_still_in_play, "Original Punglynd Child should no longer be in play"):
		return false
	
	print("✅ Replace with insufficient gold test passed!")
	return true

func test_replace_ui_optional_selection() -> bool:
	"""Test that Replace UI allows optional selection - confirm button works even with no selection"""
	print("=== Testing Replace UI Optional Selection ===")
	
	# Step 1: Setup - create a child in play and add grown-up type
	var child_card = createCardFromName("Punglynd Child")
	GameUtility.reparentWithoutMoving(child_card, game.player_base)
	child_card.setFlip(true)
	child_card.getAnimator().make_small()
	if not assert_test_not_null(child_card, "Child card should be created"):
		return false
	
	# Add grown-up subtype to make it a better Replace target
	child_card.cardData.subtypes.append("Grown-up")
	if not assert_test_true("Grown-up" in child_card.cardData.subtypes, "Child should have Grown-up subtype"):
		return false
	
	# Step 2: Add childbearer to hand and set gold to normal amount
	var childbearer_card = createCardFromName("Punglynd Childbearer")
	addCardToHand(childbearer_card)
	if not assert_test_not_null(childbearer_card, "Childbearer should be in hand"):
		return false
	
	setPlayerGold(3) # Enough for normal casting, not enough without Replace
	
	# Step 3: Store initial state
	var initial_hand_count = game.player_hand.get_children().size()
	var initial_base_count = game.player_base.getCards().size()
	
	# Step 4: Start casting process without pre-selections (should trigger UI)
	print("🎮 Starting card casting process - expecting UI to appear...")
	
	# Create a flag to track if card play completed
	var card_play_completed = false
	
	# Start the card play in a separate coroutine
	var play_card_async = func():
		await game.tryPlayCard(childbearer_card, game.player_base)
		card_play_completed = true
		print("✅ Card play process completed")
	
	play_card_async.call()
	
	# Step 5: Wait a few frames for UI to appear and check it's visible
	var ui_appeared = false
	var confirm_enabled = false
	
	for frame in range(10): # Give it time to show UI
		await get_tree().process_frame
		
		if game.selection_manager.is_selecting():
			print("✅ Selection UI appeared as expected!")
			ui_appeared = true
			
			# Check if confirm button is enabled (it should be since Replace is optional)
			if game.selection_manager.selection_ui:
				var validate_button = game.selection_manager.selection_ui.get_node_or_null("ValidateButton")
				if validate_button and not validate_button.disabled:
					print("✅ Confirm button is enabled as expected!")
					confirm_enabled = true
					
					# Step 6: Click the confirm button without selecting anything (choose normal casting)
					print("🖱️ Clicking confirm button to choose normal casting...")
					game.selection_manager._on_validate_pressed()
					break
				else:
					print("❌ Confirm button is disabled or not found")
					break
		
	if not assert_test_true(ui_appeared, "Selection UI should have appeared"):
		return false
	
	if not assert_test_true(confirm_enabled, "Confirm button should be enabled for optional Replace"):
		return false
	
	# Step 7: Wait for card play to complete
	var timeout = 50  # Maximum frames to wait
	while not card_play_completed and timeout > 0:
		await get_tree().process_frame
		timeout -= 1
	
	if not assert_test_true(card_play_completed, "Card play should have completed"):
		return false
	
	await get_tree().process_frame
	
	# Step 8: Verify final state - both cards should be in play (normal casting)
	var final_hand_count = game.player_hand.get_children().size()
	var final_base_count = game.player_base.getCards().size()
	
	if not assert_test_equal(final_hand_count, initial_hand_count - 1, "Hand should have one less card"):
		return false
	
	if not assert_test_equal(final_base_count, initial_base_count + 1, "Base should have one more card (childbearer)"):
		return false
	
	# Step 9: Verify both child and childbearer are in play
	if not assertCardExists("Punglynd Child", "play"):
		return false
	
	if not assertCardExists("Punglynd Childbearer", "play"):
		return false
	
	# Step 10: Verify player spent normal gold cost (3) not reduced cost
	var expected_gold = 0  # Started with 3, spent 3 for normal casting
	if not assert_test_equal(game.game_data.player_gold.getValue(), expected_gold, "Should have spent full cost for normal casting"):
		return false
	
	print("✅ Replace UI optional selection test passed!")
	return true

func test_eyepatch_cast_from_deck():
	"""Test Eyepatch the Pirate casting itself from deck when another goblin enters play
	
	Test scenario:
	1. Add Eyepatch the Pirate to player's deck
	2. Play a Goblin token from hand
	3. Verify Eyepatch triggers from deck and casts itself
	4. Verify Eyepatch enters the battlefield (player base)
	"""
	print("=== Testing Eyepatch Cast from Deck ===")
	
	# Step 1: Get Eyepatch card data and add it to deck
	var eyepatch_data = CardLoaderAL.getCardByName("Eyepatch the Pirate")
	if not assert_test_not_null(eyepatch_data, "Eyepatch the Pirate card should exist"):
		return false
	
	# Duplicate the card data and add it to player's deck
	var eyepatch_copy = game.createCardData(eyepatch_data)
	game.deck.add_card(eyepatch_copy)
	print("📚 Added Eyepatch to deck. Deck size: ", game.deck.cards.size())
	
	# Step 2: Give player gold and create a goblin token to play
	setPlayerGold(10)
	var goblin_token = createCardFromName("Goblin")
	if not assert_test_not_null(goblin_token, "Goblin token should be created"):
		return false
	
	addCardToHand(goblin_token)
	print("🃏 Added Goblin token to hand")
	
	# Step 3: Count cards in play before
	var initial_base_count = game.player_base.get_children().filter(func(c): return c is Card).size()
	print("📊 Initial battlefield count: ", initial_base_count)
	
	# Step 4: Play the goblin token - this should trigger Eyepatch from deck
	print("🎲 Playing Goblin token...")
	await game.tryPlayCard(goblin_token, game.player_base)
	
	# Wait for trigger resolution
	await get_tree().create_timer(0.5).timeout
	
	# Step 5: Verify Eyepatch is no longer in deck
	var eyepatch_in_deck = game.deck.cards.any(func(card): return card.cardName == "Eyepatch the Pirate")
	if not assert_test_false(eyepatch_in_deck, "Eyepatch should have been removed from deck"):
		return false
	print("✅ Eyepatch removed from deck")
	
	# Step 6: Verify Eyepatch is now on battlefield
	var cards_in_play = game.player_base.get_children().filter(func(c): return c is Card)
	var eyepatch_in_play = cards_in_play.any(func(card): return card.cardData.cardName == "Eyepatch the Pirate")
	if not assert_test_true(eyepatch_in_play, "Eyepatch should be on battlefield"):
		return false
	print("✅ Eyepatch entered battlefield")
	
	# Step 7: Verify both cards are in play (Goblin + Eyepatch)
	var final_base_count = cards_in_play.size()
	if not assert_test_equal(final_base_count, initial_base_count + 2, "Should have 2 new cards (Goblin + Eyepatch)"):
		return false
	print("✅ Both Goblin and Eyepatch are in play")
	
	# Step 8: Verify the goblin token is also in play
	var goblin_in_play = cards_in_play.any(func(card): return card.cardData.cardName == "goblin")
	if not assert_test_true(goblin_in_play, "Goblin token should be on battlefield"):
		return false
	print("✅ Goblin token confirmed in play")
	
	print("✅ Eyepatch cast from deck test passed!")
	return true

func test_goblin_emblem_replacement_effect():
	"""Test Goblin Emblem replacement effect - creating extra tokens
	
	Test scenario:
	1. Play Goblin Emblem to battlefield (has replacement effect)
	2. Play Goblin Pair from hand (creates 1 Goblin token on enter)
	3. Verify that 2 Goblin tokens were created instead of 1 (Emblem's +1 effect)
	4. Total cards in play should be: Goblin Emblem + Goblin Pair + 2 Goblin tokens = 4
	"""
	print("=== Testing Goblin Emblem Replacement Effect ===")
	
	# Step 1: Give player plenty of gold
	setPlayerGold(99)
	
	# Step 2: Create and play Goblin Emblem
	var emblem_card = createCardFromName("Goblin Emblem")
	if not assert_test_not_null(emblem_card, "Goblin Emblem should be created"):
		return false
	
	addCardToHand(emblem_card)
	print("🃏 Playing Goblin Emblem...")
	await game.tryPlayCard(emblem_card, game.player_base)
	
	# Verify Goblin Emblem is in play
	if not assertCardExists("Goblin Emblem", "play"):
		return false
	print("✅ Goblin Emblem in play")
	
	# Count cards before playing Goblin Pair
	var cards_before = game.player_base.getCards().size()
	print("📊 Cards in play before Goblin Pair: ", cards_before)
	
	# Step 3: Create and play Goblin Pair
	var goblin_pair = createCardFromName("Goblin pair")
	if not assert_test_not_null(goblin_pair, "Goblin Pair should be created"):
		return false
	
	addCardToHand(goblin_pair)
	print("🃏 Playing Goblin Pair (should trigger token creation with replacement effect)...")
	await game.tryPlayCard(goblin_pair, game.player_base)
	
	# Wait for triggers to resolve
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	
	# Step 4: Count all cards in play
	var all_cards = game.player_base.getCards()
	var total_cards = all_cards.size()
	
	print("📊 Cards in play after Goblin Pair: ", total_cards)
	
	# Debug: Print all cards
	print("🔍 Cards in play:")
	for card in all_cards:
		print("  - ", card.cardData.cardName)
	
	# Step 5: Count Goblin tokens specifically
	var goblin_tokens = all_cards.filter(func(card): 
		return card.cardData.cardName.to_lower() == "goblin" and card.isToken
	)
	var token_count = goblin_tokens.size()
	
	print("📊 Goblin tokens created: ", token_count)
	
	# Step 6: Verify 2 Goblin tokens were created (1 base + 1 from replacement effect)
	if not assert_test_equal(token_count, 2, "Should have created 2 Goblin tokens (1 base + 1 from Goblin Emblem)"):
		return false
	print("✅ Correct number of tokens created")
	
	# Step 7: Verify total cards (Goblin Emblem + Goblin Pair + 2 Goblin tokens = 4)
	var expected_total = cards_before + 3  # +1 for Goblin Pair, +2 for tokens
	if not assert_test_equal(total_cards, expected_total, "Should have Goblin Emblem + Goblin Pair + 2 tokens"):
		return false
	
	# Step 8: Verify all expected cards exist
	if not assertCardExists("Goblin Emblem", "play"):
		return false
	if not assertCardExists("Goblin pair", "play"):
		return false
	
	print("✅ Goblin Emblem replacement effect test passed!")
	return true

func test_warcamp_activated_ability() -> bool:
	"""Test Punglynd Warcamp's activated ability with tap and sacrifice cost"""
	print("=== Testing Warcamp Activated Ability ===")
	
	# Step 1: Create Warcamp card in play
	var warcamp_card = createCardFromName("Punglynd Warcamp", true)
	if not assert_test_not_null(warcamp_card, "Should create Punglynd Warcamp"):
		return false
	
	GameUtility.reparentWithoutMoving(warcamp_card, game.player_base)
	warcamp_card.setFlip(true)
	warcamp_card.getAnimator().make_small()
	await get_tree().process_frame
	
	# Step 2: Create Punglynd Child token in play (without Grown-up subtype initially)
	var child_card:Card = createCardFromName("Punglynd Child", true)
	if not assert_test_not_null(child_card, "Should be able to create Punglynd Child card"):
		return false
	
	GameUtility.reparentWithoutMoving(child_card, game.player_base)
	child_card.setFlip(true)
	child_card.getAnimator().make_small()
	await get_tree().process_frame
	
	# Verify child does not have Grown-up subtype initially
	if not assert_test_false("Grown-up" in child_card.cardData.subtypes, "Child should not have Grown-up subtype initially"):
		return false
	
	# Step 3: Add Goblin Pair to deck
	game.deck.cards.clear()
	game.deck.update_size()
	
	var goblin_pair_data = CardLoaderAL.getCardByName("Goblin Pair")
	if not assert_test_not_null(goblin_pair_data, "Should be able to load Goblin Pair"):
		return false
	
	addCardToDeck(goblin_pair_data, true)
	
	if not assert_test_equal(game.deck.get_card_count(), 1, "Deck should have 1 card"):
		return false
	
	# Step 4: Find Warcamp's activated ability
	var activated_ability = null
	if warcamp_card.cardData.activated_abilities.size() > 0:
		activated_ability=warcamp_card.cardData.activated_abilities[0]
	
	if not assert_test_not_null(activated_ability, "Warcamp should have activated ability"):
		return false
	
	# Verify the ability has the correct effect type (Draw)
	var effect_type_str = EffectType.type_to_string(activated_ability.effect_type)
	if not assert_test_equal(effect_type_str, "Draw", "Ability should be Draw effect"):
		return false
	
	# Step 5: Try to activate the ability - should fail because child is not a valid sacrifice target
	print("🔍 Attempting to activate ability without valid sacrifice target...")
	var can_pay = CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, warcamp_card)
	if not assert_test_false(can_pay, "Should not be able to activate ability without valid sacrifice target"):
		return false
	print("✅ Ability correctly prevented when no valid targets")
	
	# Step 6: Add Grown-up subtype to the child token
	print("📝 Adding Grown-up subtype to child token...")
	child_card.cardData.subtypes.append("Grown-up")
	child_card.updateDisplay()  # Update the visual display
	await get_tree().process_frame
	
	if not assert_test_true("Grown-up" in child_card.cardData.subtypes, "Child should have Grown-up subtype now"):
		return false
	
	# Step 7: Verify ability can now be activated
	print("🔍 Checking if ability can be activated now...")
	can_pay = CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, warcamp_card)
	if not assert_test_true(can_pay, "Should be able to activate ability with valid sacrifice target"):
		return false
	print("✅ Ability can be activated with valid target")
	
	# Step 8: Store initial state
	var initial_hand_count = game.player_hand.get_child_count()
	var initial_base_count = game.player_base.getCards().size()
	
	# Verify warcamp is untapped
	if not assert_test_false(warcamp_card.cardData.is_tapped(), "Warcamp should be untapped"):
		return false
	
	# Step 9: Create pre-selection for the sacrifice (child token)
	print("🎮 Activating Warcamp ability with child sacrifice...")
	var selections = SelectionManager.CardPlaySelections.new()
	selections.sacrifice_targets.push_back(child_card)
	
	# Activate the ability with pre-selections
	await AbilityManagerAL.activateAbility(warcamp_card, activated_ability, game, selections)
	await get_tree().process_frame
	
	# Step 10: Verify warcamp is now tapped
	if not assert_test_true(warcamp_card.cardData.is_tapped(), "Warcamp should be tapped after activation"):
		return false
	print("✅ Warcamp is tapped")
	
	# Step 11: Verify child was sacrificed (removed from play)
	var cards_in_base = game.player_base.getCards()
	var child_still_in_play = false
	for card in cards_in_base:
		if card == child_card:
			child_still_in_play = true
			break
	
	if not assert_test_false(child_still_in_play, "Child token should have been sacrificed"):
		return false
	print("✅ Child token was sacrificed")
	
	# Step 12: Verify base count decreased by 1 (child removed)
	var final_base_count = game.player_base.getCards().size()
	if not assert_test_equal(final_base_count, initial_base_count - 1, "Base should have one less card"):
		return false
	
	# Step 13: Verify card was drawn (hand increased by 1)
	var final_hand_count = game.player_hand.get_child_count()
	if not assert_test_equal(final_hand_count, initial_hand_count + 1, "Hand should increase by 1"):
		return false
	print("✅ Card was drawn")
	
	# Step 14: Verify the drawn card is Goblin Pair
	var drawn_card = game.player_hand.get_children()[-1] as Card
	if not assert_test_not_null(drawn_card, "Should have drawn a card"):
		return false
	
	if not assert_test_equal(drawn_card.cardData.cardName.to_lower(), "goblin pair", "Drawn card should be Goblin Pair"):
		return false
	print("✅ Goblin Pair was drawn")
	
	print("✅ Warcamp activated ability test passed!")
	return true
