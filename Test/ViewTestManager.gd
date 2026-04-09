extends BaseTestManager
class_name ViewTestManager

# No @onready - UI references will be set by TestGameRunner

func is_headless_mode() -> bool:
	"""View tests always run in non-headless mode (with animations)"""
	return false

func runTests():
	"""Automatically discovers and runs all view tests with animations"""
	print("=== Starting View Test Suite (with animations) ===")
	test_results.clear()
	
	var test_methods = _discover_test_methods()
	var passed = 0
	var failed = 0
	
	for test_method in test_methods:
		var result = await _run_single_test(test_method, false)  # Always with animations
		test_results.append(result)
		session_test_results[test_method] = result
		
		if result.passed:
			passed += 1
			print("✅ PASSED: ", test_method, " (", result.duration_ms, "ms)")
		else:
			failed += 1
			print("❌ FAILED: ", test_method, " - ", result.error)
	
	print("\n=== View Test Results ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("Total: ", passed + failed)
	
	return {"passed": passed, "failed": failed, "results": test_results}

# === VIEW TESTS (Animation and visual feedback tests) ===

func test_animation_completion():
	"""Test that card animations complete properly and take measurable time"""
	var card = createCardFromName("goblin pair", GameZone.e.HAND_PLAYER)
	setPlayerGold(3)
	
	var start_time = Time.get_ticks_msec()
	await game.tryPlayCard(card, GameZone.e.BATTLEFIELD_PLAYER)
	var end_time = Time.get_ticks_msec()
	
	# Should take some time for animation: ~1s base duration, divided by animation speed
	var min_expected_ms = 500.0 / CardAnimator.ANIMATION_SPEED
	if not assert_test(end_time - start_time > min_expected_ms, "Animation should take some time " + str(end_time-start_time) + "ms"):
		return false
	
	assertCardExists("Goblin pair", "play")
	return true

func test_goblin_boss_extra_deck_casting():
	"""Test playing Goblin Boss from extra deck with proper selection"""
	# Setup: Give player plenty of gold
	setPlayerGold(99)
	
	# Step 1: Play 2 Goblin Pairs to get 4 goblins total (2 pairs + 2 tokens)
	addCardToExtraDeck(CardLoaderAL.getCardByName("Goblin Boss"))
	var goblin_pair_1 = createCardFromName("goblin pair", GameZone.e.HAND_PLAYER)
	
	# Play first Goblin Pair and wait for animation to complete
	await game.tryPlayCard(goblin_pair_1, GameZone.e.BATTLEFIELD_PLAYER)
	if not assertCardCount(2, "play"):  # Should have 2 goblins now
		return false
	
	# Step 2: Show extra deck hand directly (bypass outline visibility check)
	game.game_view.show_extra_hand()
	var castable_cards: Array[CardData] = []
	for card_data: CardData in game.game_data.get_cards_in_zone(GameZone.e.EXTRA_DECK_PLAYER):
		castable_cards.append(card_data)
	await game.game_view.arrange_extra_deck_hand(castable_cards, game.game_view.create_card_view)

	# Step 3: Assert that Goblin Boss appears in extra hand display
	var extra_hand_cards = game.game_view.extra_hand.get_children().filter(func(child): return child is Card)
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
	var goblins_before = getCardsInPlayData().filter(func(card_data:CardData): return card_data.hasSubtype("Goblin")).size()
	if not assert_test(goblins_before >= 2, "Should have at least 2 goblins before casting boss"):
		return false
	
	# Get the first 2 goblin cards for selection
	var goblins_in_play = getCardsInPlayData().filter(func(card_data): return card_data.hasSubtype("Goblin"))
	if not assert_test(goblins_in_play.size() >= 2, "Should have at least 2 goblins to sacrifice"):
		return false
	
	# Prepare selection data with the two goblins to sacrifice
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_sacrifice_target(goblins_in_play[0])
	selections.add_sacrifice_target(goblins_in_play[1])
	
	await game.tryPlayCard(goblin_boss_card.cardData, GameZone.e.BATTLEFIELD_PLAYER, selections)
	
	# Step 5: Assert final state
	var final_cards = getCardsInPlayData()
	var boss_found = final_cards.filter(func(c: CardData): return c.cardName == "Goblin Boss").size() >= 1
	
	if not assert_test_true(boss_found, "Goblin Boss should be in play"):
		return false
	if not assert_test_equal(final_cards.size(), 1, "Should have exactly 1 card in play: Goblin Boss"):
		return false

func test_combat_zone_button_click():
	"""Test clicking combat zone resolve button changes zone resolution state"""
	# Setup: Create a creature and place it in a combat zone
	setPlayerGold(99)
	
	# Get the first combat zone and place the card there via proper game mechanics
	var combat_zone = game.game_view.combat_zones[0] as CombatZone
	var first_ally_spot: GridContainer3D = combat_zone.getFirstEmptyLocation(true)
	var card_template = CardLoaderAL.getCardByName("goblin pair")
	var card_data = game.createCardData(card_template, GameZone.e.BATTLEFIELD_PLAYER, true)
	var zone_index = game.game_view.get_combat_zones().find(combat_zone)
	var dest_zone = (GameZone.e.COMBAT_PLAYER_1 + zone_index) as GameZone.e
	await game.execute_move_card(card_data, dest_zone)

	var card_in_spot = first_ally_spot.get_child(0)
	if not assert_test_equal(card_in_spot, card_data.get_card_object(), "Card should be placed in the combat spot (VIEW LAYER)"):
		return false
	
	# Check initial state - combat should not be resolved (DATA LAYER)
	if not assert_test_false(game.game_data.is_combat_resolved(combat_zone), "Combat should initially be unresolved"):
		return false
	
	# Click the combat button and wait for resolution
	await clickCombatButton(combat_zone)
	
	# Verify the combat zone state has changed - it should now be resolved (DATA LAYER)
	if not assert_test_true(game.game_data.is_combat_resolved(combat_zone), "Combat should be resolved after clicking the button"):
		return false
	
	return true

func test_replace_ui_optional_selection() -> bool:
	"""Test that Replace UI allows optional selection - confirm button works even with no selection"""
	
	# Setup - create a child in play and add grown-up type
	var child_card = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Add grown-up subtype to make it a better Replace target
	child_card.addSubtype("Grown-up")
	if not assert_test_true("Grown-up" in child_card.subtypes, "Child should have Grown-up subtype"):
		return false
	
	# Add childbearer to hand and set gold to normal amount
	var childbearer_card = createCardFromName("Punglynd Childbearer", GameZone.e.HAND_PLAYER)
	
	setPlayerGold(3) # Enough for normal casting
	
	# Store initial state
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	var initial_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	# Simulate user clicking confirm on the Replace UI without selecting a target (normal casting)
	# Use call_deferred so _on_validate_pressed fires AFTER await selection_completed is set up
	# (selection_started emits before the await line is reached, so sync calls won't work)
	game.selection_manager.selection_started.connect(
		func():
			game.selection_manager.call_deferred("_on_validate_pressed"),
		CONNECT_ONE_SHOT
	)
	
	# Play the childbearer card - will open Replace UI, our handler confirms it immediately
	await game.tryPlayCard(childbearer_card, GameZone.e.BATTLEFIELD_PLAYER)
	await test_runner.get_tree().process_frame
	
	# Verify final state - both cards should be in play (normal casting)
	var final_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	var final_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	if not assert_test_equal(final_hand_count, initial_hand_count - 1, "Hand should have one less card"):
		return false
	
	# Note: Childbearer creates a token when it enters play, so +2 cards (childbearer + token)
	if not assert_test_equal(final_base_count, initial_base_count + 2, "Base should have two more cards (childbearer + token)"):
		return false
	
	# Verify both child and childbearer are in play
	if not assertCardExists("Punglynd Child", "play"):
		return false
	
	if not assertCardExists("Punglynd Childbearer", "play"):
		return false
	
	# Verify player spent normal gold cost (3-2=1)
	var expected_gold = 1
	if not assert_test_equal(game.game_data.player_gold.getValue(), expected_gold, "Should have spent full cost for normal casting"):
		return false
	
	print("✅ Replace UI optional selection test passed!")
	return true
