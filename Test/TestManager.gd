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
	assert(card_data != null, "Card not found: " + card_name)
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
	var c = game.createCardFromData(cardData, true)
	addCardToHand(c)
	game.game_data.player_gold.setValue(99)
	await game.tryPlayCard(c, game.player_base)
	var cardsInPlay = game.player_base.getCards()
	assert(cardsInPlay.size() == 2, "Goblin Pair should spawn 2 cards")

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
	assertCardCount(2, "play")  # Should have 2 goblins now
	
	
	# Step 2: Assert that Goblin Boss appears in extra deck display
	var extra_deck_cards = game.extra_deck_display.get_children().filter(func(child): return child is Card)
	var goblin_boss_found = false
	var goblin_boss_card: Card = null
	
	for card in extra_deck_cards:
		if card.cardData.cardName == "Goblin Boss":
			goblin_boss_found = true
			goblin_boss_card = card
			break
	
	assert(goblin_boss_found, "Goblin Boss should be displayed in extra deck when 2+ goblins are in play")
	
	# Step 3: Attempt to play Goblin Boss from extra deck
	# This should trigger selection for the additional cost (sacrifice 2 goblins)
	var goblins_before = getCardsInPlay().filter(func(card:Card): return card.cardData.hasSubtype("Goblin")).size()
	assert(goblins_before >= 2, "Should have at least 2 goblins before casting boss")
	
	# Get the first 2 goblin cards for selection
	var goblins_in_play = getCardsInPlay().filter(func(card): return card.cardData.hasSubtype("Goblin"))
	assert(goblins_in_play.size() >= 2, "Should have at least 2 goblins to sacrifice")
	
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
	
	assert(boss_found, "Goblin Boss should be in play")
	assert(final_cards.size() == 1, "Should have exactly 1 card in play: Goblin Boss")

func test_combat_zone_button_click():
	"""Test clicking combat zone resolve button changes zone resolution state"""
	# Setup: Create a creature and place it in a combat zone
	var card = createTestCard("goblin pair")
	setPlayerGold(99)
	
	# Get the first combat zone and place the card there
	var combat_zone = game.combatZones[0] as CombatZone
	var first_ally_spot = combat_zone.getFirstEmptyLocation(true)
	assert(first_ally_spot != null, "Should have an empty ally spot available")
	
	# Place the card directly in the combat zone
	first_ally_spot.setCard(card)
	await get_tree().process_frame  # Wait for the UI to update
	
	# Verify the card is in the combat zone
	assert(first_ally_spot.getCard() == card, "Card should be placed in the combat zone")
	
	# Check initial state - combat should not be resolved
	assert(!game.game_data.is_combat_resolved(combat_zone), "Combat should initially be unresolved")
	
	# Click the combat button and wait for resolution
	await clickCombatButton(combat_zone)
	
	# Verify the combat zone state has changed - it should now be resolved
	assert(game.game_data.is_combat_resolved(combat_zone), "Combat should be resolved after clicking the button")
	
	# Verify the button display has been updated
	var resolve_button = combat_zone.resolve_fight_button
	assert(resolve_button.resolve_fight.modulate == Color.GREEN, "Button color should change to green after resolution")

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
	assert(combat_zone_1 != combat_zone_2, "Should have different combat zones")
	
	# Play goblin1 to first combat location
	var first_ally_spot_1 = combat_zone_1.getFirstEmptyLocation(true)
	assert(first_ally_spot_1 != null, "First combat zone should have an empty ally spot")
	await game.tryPlayCard(goblin1, first_ally_spot_1)
	
	# Play goblin2 to second combat location
	var first_ally_spot_2 = combat_zone_2.getFirstEmptyLocation(true)
	assert(first_ally_spot_2 != null, "Second combat zone should have an empty ally spot")
	await game.tryPlayCard(goblin2, first_ally_spot_2)
	
	# Verify both cards are in their respective zones
	assert(first_ally_spot_1.getCard() == goblin1, "Goblin1 should be in first combat zone")
	assert(first_ally_spot_2.getCard() == goblin2, "Goblin2 should be in second combat zone")
	
	# Check initial state - both combats should be unresolved
	assert(!game.game_data.is_combat_resolved(combat_zone_1), "Combat zone 1 should initially be unresolved")
	assert(!game.game_data.is_combat_resolved(combat_zone_2), "Combat zone 2 should initially be unresolved")
	
	# Store initial combat zone data for comparison
	var initial_zone_2_data = game.game_data.get_combat_zone_data(combat_zone_2)
	var initial_player_capture_current = initial_zone_2_data.player_capture_current
	
	# Click the first combat zone's button to resolve it
	await clickCombatButton(combat_zone_1)
	
	# Verify only the first combat zone was resolved
	assert(game.game_data.is_combat_resolved(combat_zone_1), "Combat zone 1 should be resolved after clicking its button")
	assert(!game.game_data.is_combat_resolved(combat_zone_2), "Combat zone 2 should remain unresolved")
	
	# Get the resolve fight buttons from both combat zones for button state verification
	var resolve_button_1 = combat_zone_1.resolve_fight_button
	var resolve_button_2 = combat_zone_2.resolve_fight_button
	assert(resolve_button_1.resolve_fight.text == "DONE", "Button 1 text should change to DONE after resolution")
	assert(resolve_button_1.resolve_fight.modulate == Color.GREEN, "Button 1 color should change to green after resolution")
	assert(resolve_button_2.resolve_fight.text == "FIGHT", "Button 2 text should remain FIGHT")
	assert(resolve_button_2.resolve_fight.modulate == Color.WHITE, "Button 2 color should remain white")
	
	# Verify that the second combat zone's data in GameData hasn't changed
	var final_zone_2_data = game.game_data.get_combat_zone_data(combat_zone_2)
	assert(final_zone_2_data.player_capture_current == initial_player_capture_current, 
		"Second combat zone's player_capture_current should not have changed")
