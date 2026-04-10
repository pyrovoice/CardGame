extends Control
class_name BaseTestManager

var game: Game
var test_results: Array[Dictionary] = []
var session_test_results: Dictionary = {}  # Track results by test name for the session
var test_runner: TestGameRunner  # Reference to the test runner
var current_test_failed: bool = false  # Track if current test failed
var current_test_error: String = ""    # Store current test error message

# UI References (to be set by subclasses if needed)
var run_all_button: Button
var run_failed_button: Button
var test_grid_container: GridContainer
var failed_tests_2: Button

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

# === TEST EXECUTION INFRASTRUCTURE ===

func runTests():
	"""Automatically discovers and runs all test methods - override in subclass"""
	push_error("runTests() must be implemented in subclass")
	return {"passed": 0, "failed": 0, "results": []}

func runFailedTests():
	"""Run only the tests that failed in the current session"""
	print("=== Running Failed Tests ===")
	
	var failed_tests = []
	for test_name in session_test_results.keys():
		if not session_test_results[test_name].passed:
			failed_tests.append(test_name)
	
	if failed_tests.is_empty():
		print("✨ No failed tests to rerun!")
		return {"passed": 0, "failed": 0, "results": []}
	
	test_results.clear()
	var passed = 0
	var failed = 0
	
	for test_method in failed_tests:
		var result = await _run_single_test(test_method, is_headless_mode())
		test_results.append(result)
		session_test_results[test_method] = result
		
		if result.passed:
			passed += 1
			print("✅ NOW PASSED: ", test_method, " (", result.duration_ms, "ms)")
		else:
			failed += 1
			print("❌ STILL FAILED: ", test_method, " - ", result.error)
	
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
		var result = await _run_single_test(test_method, is_headless_mode())
		test_results.append(result)
		session_test_results[test_method] = result
		
		if result.passed:
			passed += 1
			print("✅ PASSED: ", test_method, " (", result.duration_ms, "ms)")
		else:
			failed += 1
			print("❌ FAILED: ", test_method, " - ", result.error)
			print("⚠️ Stopping on first failure")
			break
	
	print("\n=== Test Results (Stopped on Failure) ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("Total Run: ", passed + failed)
	print("Total Tests: ", test_methods.size())
	
	return {"passed": passed, "failed": failed, "results": test_results}

func _discover_test_methods() -> Array[String]:
	"""Automatically find all methods that start with 'test'"""
	var test_methods: Array[String] = []
	var method_list = get_method_list()
	
	for method_info in method_list:
		var method_name = method_info["name"]
		if method_name.begins_with("test_"):
			test_methods.append(method_name)
	
	return test_methods

func _run_single_test(test_method: String, headless: bool = false) -> Dictionary:
	"""Run a single test and capture its result
	
	Args:
		test_method: Name of the test method to run
		headless: If true, runs without animations/view updates (faster). If false, shows animations.
	"""
	var result = {
		"test": test_method,
		"passed": false,
		"error": "",
		"start_time": Time.get_ticks_msec(),
		"end_time": 0,
		"duration_ms": 0
	}

	print("Starting: ", test_method)
	
	# Reset test failure tracking
	current_test_failed = false
	current_test_error = ""
	
	# Create fresh game instance for this test
	if test_runner:
		# Destroy any existing game instance
		await test_runner.cleanup_game()
		# Create a brand new game instance
		game = await test_runner.ensure_game_loaded()
		game.game_view.headless = headless
		await test_runner.get_tree().process_frame
	
	# Execute the test method
	if has_method(test_method):
		var test_result = await call(test_method)
		
		# Check if test explicitly returned false or if an assertion failed
		if current_test_failed:
			result.passed = false
			result.error = current_test_error
		elif test_result == false:
			result.passed = false
			result.error = "Test returned false"
		else:
			result.passed = true
	else:
		result.error = "Test method not found"
	
	result["end_time"] = Time.get_ticks_msec()
	result["duration_ms"] = result.end_time - result.start_time
	
	return result

func is_headless_mode() -> bool:
	"""Override in subclass to specify headless mode preference"""
	return false

# === TEST HELPER METHODS ===

func createCardFromName(card_name: String, target_zone: GameZone.e, player_controlled: bool = true) -> CardData:
	"""Universal helper to create a card from either token or card name"""
	var card_data = CardLoaderAL.getCardByName(card_name)
	if not assert_test_not_null(card_data, "Failed to create card:" + card_name):
		return null
	
	# Use createCardData to properly duplicate and register abilities
	if target_zone == GameZone.e.UNKNOWN:
		return null  # Invalid target zone
	var duplicated_card_data = game.createCardData(card_data, target_zone, player_controlled)
	if not duplicated_card_data:
		return null
	
	return duplicated_card_data

func createTestCard(card_name: String, cost: int = 0, power: int = 0, types: Array[CardData.CardType] = [CardData.CardType.CREATURE]) -> CardData:
	"""Create a test card with specified properties without loading from file"""
	var card_data = CardData.new()
	card_data.cardName = card_name
	card_data.goldCost = cost
	card_data._power = power
	card_data._types = types.duplicate()
	return game.createCardData(card_data, GameZone.e.HAND_PLAYER, true)

func addCardToHand(card: Card):
	"""Helper to add card to player hand"""
	game.game_data.add_card_to_zone(card.cardData, GameZone.e.HAND_PLAYER)
	GameUtility.reparentWithoutMoving(card, game.game_view.player_hand)

func addCardToBattlefield(card: Card, player_side: bool = true):
	"""Helper to add card to battlefield"""
	var zone = GameZone.e.BATTLEFIELD_PLAYER if player_side else GameZone.e.BATTLEFIELD_OPPONENT
	var target_base = game.game_view.player_base if player_side else game.game_view.opponent_base
	game.game_data.add_card_to_zone(card.cardData, zone)
	GameUtility.reparentWithoutMoving(card, target_base)
	
func addCardToExtraDeck(card: CardData):
	card.playerOwned = true
	card.playerControlled = true
	game.game_data.add_card_to_zone(card, GameZone.e.EXTRA_DECK_PLAYER)

func addCardToDeck(card_data: CardData, player_deck: bool = true):
	"""Helper to add card to deck"""
	var deck = game.game_view.deck if player_deck else game.game_view.deck_opponent
	# Set proper ownership and control flags for the card data
	card_data.playerOwned = player_deck
	card_data.playerControlled = player_deck
	var deck_zone = GameZone.e.DECK_PLAYER if player_deck else GameZone.e.DECK_OPPONENT
	game.game_data.add_card_to_zone(card_data, deck_zone)
	deck.update_size()

func add_card_to_zone(card_data: CardData, zone: GameZone.e):
	"""Add a card directly to a zone for test setup
	
	Use this to set up test state. Does not emit game events or trigger abilities.
	For gameplay movement with events/triggers, use game.execute_move_card().
	
	Args:
		card_data: The CardData to move
		zone: Target zone enum
	"""
	if not card_data:
		push_error("add_card_to_zone: card_data is null")
		return
	
	# Directly update GameData for test setup
	game.game_data.add_card_to_zone(card_data, zone)
	
	if game.game_view.headless:
		return  # Skip view updates in headless mode

func play_card_from_data(card_data: CardData, from_zone: GameZone.e = GameZone.e.HAND_PLAYER, pay_cost: bool = true) -> bool:
	"""Play a card using CardData - test utility for programmatic card play
	
	Use this in tests to play cards without user interaction.
	Works in both headless and normal mode.
	
	Args:
		card_data: The CardData to play
		from_zone: The zone the card is being played from (default: HAND_PLAYER)
		pay_cost: Whether to actually pay the card's cost (default: true)
	
	Returns:
		bool: True if play was successful
	"""
	if not card_data:
		push_error("play_card_from_data: card_data is null")
		return false
	
	print("🎮 [TEST] Playing card: ", card_data.cardName)
	
	# Use game.tryPlayCard which handles all payment and play logic
	await game.tryPlayCard(card_data, GameZone.e.BATTLEFIELD_PLAYER, null, pay_cost)
	
	print("✅ [TEST] Card play complete")
	return true
	
func setPlayerGold(amount: int):
	"""Helper to set player gold"""
	game.game_data.player_gold.setValue(amount)

func simulateCardSelection(target_card: Card) -> bool:
	"""Simulate player selecting a specific card during selection process"""
	if not game.selection_manager.is_selecting():
		print("❌ Not currently in selection mode")
		return false
	
	# Simulate clicking the target card
	game.selection_manager.handle_card_click(target_card)
	
	# Wait a frame for the selection to process
	await test_runner.get_tree().process_frame
	
	# Check if selection is complete and validate
	var current_selection = game.selection_manager.current_selection
	if current_selection and current_selection.is_complete:
		print("✅ Selection complete")
		return true
	else:
		print("⚠️ Selection not yet complete or invalid")
		return false

func waitForSelectionStart(max_frames: int = 10) -> bool:
	"""Wait for selection to start (useful for async operations)"""
	for i in range(max_frames):
		if game.selection_manager.is_selecting():
			return true
		await test_runner.get_tree().process_frame
	
	print("❌ Selection didn't start within ", max_frames, " frames")
	return false

func getCardsInPlay() -> Array[Card]:
	"""Helper to get all cards in play (returns Card objects from view)"""
	return game.game_view.player_base.getCards()

func getCardsInPlayData() -> Array[CardData]:
	"""Helper to get all card data in play"""
	return game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)

func assertCardCount(expected: int, zone: String = "play") -> bool:
	"""Assert the number of cards in a specific zone"""
	var actual: int
	match zone:
		"play":
			actual = getCardsInPlayData().size()
		"hand":
			actual = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
		"graveyard":
			actual = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size()
		_:
			push_error("Unknown zone: " + zone)
			return false
	
	return assert_test_equal(actual, expected, "Expected %d cards in %s, but found %d" % [expected, zone, actual])

func assertCardExists(card_name: String, zone: String = "play") -> bool:
	"""Assert that a specific card exists in a zone"""
	var found = false
	match zone:
		"play":
			for card_data in getCardsInPlayData():
				if card_data.cardName.to_lower() == card_name.to_lower():
					found = true
					break
		"hand":
			for card_data in game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER):
				if card_data.cardName.to_lower() == card_name.to_lower():
					found = true
					break
		"graveyard":
			for card_data in game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER):
				if card_data.cardName.to_lower() == card_name.to_lower():
					found = true
					break
		_:
			push_error("Unknown zone: " + zone)
			return false
	
	return assert_test_true(found, "Card '%s' not found in %s" % [card_name, zone])

func clickCombatButton(combat_zone: CombatZone):
	"""Helper method to click a combat zone's resolve button and wait for completion"""
	var resolve_button = combat_zone.resolve_fight_button
	game._on_left_click(resolve_button)
	var counter = 10
	while counter>0 && game.game_data.get_combat_zone_data(combat_zone).isCombatResolved.value == false:
		await test_runner.get_tree().process_frame
		counter -= 1
