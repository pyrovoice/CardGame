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
	# Set fast animation speed for testing (10x normal speed)
	CardAnimator.ANIMATION_SPEED = 10.0
	print("🏃 Set animation speed to 10x for testing")
	
	# Connect buttons
	run_all_button.pressed.connect(_on_run_all_tests)
	run_failed_button.pressed.connect(_on_run_failed_tests)
	
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
		game = test_runner.ensure_game_loaded()
	
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
	var card = game.createCardFromData(CardLoaderAL.duplicateCardScript(card_data), player_controlled)
	
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
	# Set proper control flags for the card data
	card_data.playerControlled = player_deck
	card_data.playerOwned = player_deck
	deck.cards.push_back(card_data)
	deck.update_size()
	
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
	var c = game.createCardFromData(CardLoaderAL.duplicateCardScript(cardData), true)
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
	var selection_data = {
		"additional_cost_selections": [goblins_in_play[0], goblins_in_play[1]] as Array[Card],
		"spell_targets": [] as Array[Card],
		"cancelled": false
	}
	
	await game.tryPlayCard(goblin_boss_card, game.player_base, selection_data)
	
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

func test_bolt_spell_with_valid_target():
	"""Test casting Bolt spell with a legal target - bolt and target should end up in graveyard"""
	# Setup: Create Bolt spell and a target creature
	var bolt_card = createTestCard("Bolt")
	var target_creature = createTestCard("goblin")
	
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
	var selection_data = {
		"additional_cost_selections": [] as Array[Card],
		"spell_targets": [target_creature] as Array[Card],
		"cancelled": false
	}
	
	# Cast Bolt targeting the creature
	await game.tryPlayCard(bolt_card, game.player_base, selection_data)
	
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
	var bolt_card = createTestCard("Bolt")
	var target_creature = createTestCard("goblin")
	
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
	var selection_data = {
		"additional_cost_selections": [] as Array[Card],
		"spell_targets": [target_creature] as Array[Card],
		"cancelled": true
	}
	
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
	await game.tryPlayCard(bolt_in_hand, game.player_base, selection_data)
	
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
	var bolt_card = createTestCard("Bolt")
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
	var drengr_card = createTestCard("Punglynd Drengr", true)
	
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
	
	# Create a valid target (1-cost creature) - using natural token data
	var token_data = CardLoaderAL.load_token_by_name("Punglynd Child")
	if not assert_test_not_null(token_data, "Should be able to load Punglynd Child token"):
		return false
	
	var target_creature = game.createCardFromData(CardLoaderAL.duplicateCardScript(token_data), true)
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
	var drengr_card = createTestCard("Punglynd Drengr", true)
	
	# Get Replace cost data
	var replace_cost = null
	for cost in drengr_card.cardData.additionalCosts:
		if cost.get("cost_type") == "Replace":
			replace_cost = cost
			break
	
	if not assert_test(replace_cost != null, "Should find Replace cost data"):
		return false
	
	# Create a Grown-up target for extra reduction
	var d = CardLoaderAL.load_token_by_name("Punglynd Child")
	var grownup_target = game.createCardFromData(CardLoaderAL.duplicateCardScript(d), true)
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
	return true

func test_punglynd_child_growup():
	"""Test that Punglynd Child gains 'Grown-up' subtype after attacking and passing turn"""
	print("🧪 Testing Punglynd Child grow-up ability...")
	
	# Step 1: Create Punglynd Child token
	var token_data = CardLoaderAL.load_token_by_name("Punglynd Child")
	if not assert_test_not_null(token_data, "Should be able to load Punglynd Child token"):
		return false
	
	var child_card = game.createCardFromData(CardLoaderAL.duplicateCardScript(token_data), true)
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
