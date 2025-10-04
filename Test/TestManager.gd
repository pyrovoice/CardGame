extends Node
class_name TestManager

var game: Game
var test_results: Array[Dictionary] = []

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
	
	# Connect to tree's error signal temporarily
	if not get_tree().tree_process_mode_changed.is_connected(_on_test_error):
		# We'll use a custom error tracking approach instead
		pass
	
	# Run beforeEach setup
	await beforeEach()
	
	# Execute the test method
	if has_method(test_method):
		await call(test_method)
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
	
	# Reset game data
	game.game_data.player_gold.setValue(3)
	game.game_data.opponent_gold.setValue(3)
	game.game_data.player_life.setValue(10)
	game.game_data.danger_level.setValue(1)
	
	# Wait a frame for cleanup
	await get_tree().process_frame

func beforeEach():
	await resetState()

# === TEST HELPER METHODS ===

func createTestCard(card_name: String, player_controlled: bool = true) -> Card:
	"""Helper to create a card for testing"""
	var card_data = CardLoaderAL.getCardByName(card_name)
	assert(card_data != null, "Card not found: " + card_name)
	return game.createCardFromData(card_data, CardData.CardType.CREATURE, player_controlled, player_controlled)

func addCardToHand(card: Card):
	"""Helper to add card to player hand"""
	card.reparent(game.player_hand)

func setPlayerGold(amount: int):
	"""Helper to set player gold"""
	game.game_data.player_gold.setValue(amount)

func getCardsInPlay() -> Array[Card]:
	"""Helper to get all cards in play"""
	return game.player_base.getCards()

func assertCardCount(expected: int, zone: String = "play"):
	"""Assert the number of cards in a specific zone"""
	var actual: int
	match zone:
		"play":
			actual = getCardsInPlay().size()
		"hand":
			actual = game.player_hand.get_child_count()
		_:
			assert(false, "Unknown zone: " + zone)
	
	assert(actual == expected, "Expected %d cards in %s, but found %d" % [expected, zone, actual])

func assertCardExists(card_name: String, zone: String = "play"):
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
	
	assert(found, "Card '%s' not found in %s" % [card_name, zone])

# === ACTUAL TESTS ===

func test_card_creation():
	"""Test that cards can be created from card data"""
	var card = createTestCard("goblin pair")
	assert(card != null, "Card should be created")
	assert(card.cardData.cardName == "Goblin pair", "Card should have correct name")

func test_card_play_basic():
	"""Test basic card playing functionality"""
	var card = createTestCard("goblin pair")
	addCardToHand(card)
	setPlayerGold(3)
	await get_tree().process_frame
	assertCardCount(0, "play")
	assertCardCount(1, "hand")
	
	await game.tryPlayCard(card, game.player_base)
	
	assertCardCount(2, "play")
	assertCardCount(0, "hand")
	assertCardExists("Goblin pair", "play")

func test_insufficient_gold():
	"""Test that cards can't be played without enough gold"""
	var card = createTestCard("goblin pair")  # costs 3
	addCardToHand(card)
	setPlayerGold(0)  # Not enough
	
	await game.tryPlayCard(card, game.player_base)
	
	# Card should still be in hand
	assertCardCount(0, "play")
	assertCardCount(1, "hand")
	
func test_animation_completion():
	"""Test that card animations complete properly"""
	var card = createTestCard("goblin pair")
	addCardToHand(card)
	setPlayerGold(3)
	
	var start_time = Time.get_ticks_msec()
	await game.tryPlayCard(card, game.player_base)
	var end_time = Time.get_ticks_msec()
	
	# Should take some time for animation
	assert(end_time - start_time > 100, "Animation should take some time")
	assertCardExists("Goblin pair", "play")

# Add more tests as needed...

func test_goblin_pair():
	"""Test Goblin Pair card creation and spawning"""
	var cardData = CardLoaderAL.getCardByName("goblin pair")
	var c = game.createCardFromData(cardData, CardData.CardType.CREATURE, true, true)
	addCardToHand(c)
	game.game_data.player_gold.setValue(99)
	await game.tryPlayCard(c, game.player_base)
	var cardsInPlay = game.player_base.getCards()
	assert(cardsInPlay.size() == 2, "Goblin Pair should spawn 2 cards")
