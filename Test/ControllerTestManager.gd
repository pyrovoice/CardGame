extends BaseTestManager
class_name ControllerTestManager

# No @onready - UI references will be set by TestGameRunner

func is_headless_mode() -> bool:
	"""Controller tests always run in headless mode"""
	return true

func runTests():
	"""Automatically discovers and runs all controller tests in headless mode"""
	print("=== Starting Controller Test Suite (headless mode) ===")
	test_results.clear()
	
	var test_methods = _discover_test_methods()
	var passed = 0
	var failed = 0
	
	for test_method in test_methods:
		var result = await _run_single_test(test_method, true)  # Always headless
		test_results.append(result)
		session_test_results[test_method] = result
		
		if result.passed:
			passed += 1
			print("✅ PASSED: ", test_method, " (", result.duration_ms, "ms)")
		else:
			failed += 1
			print("❌ FAILED: ", test_method, " - ", result.error)
	
	print("\n=== Controller Test Results ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("Total: ", passed + failed)
	
	return {"passed": passed, "failed": failed, "results": test_results}

# === CONTROLLER TESTS (All logic/state tests) ===

func test_card_creation():
	"""Test that cards can be created from card data"""
	var card: CardData = createCardFromName("goblin pair", GameZone.e.HAND_PLAYER)
	if not assert_test_not_null(card, "Card should be created"):
		return false
	if not assert_test_equal(card.cardName, "Goblin pair", "Card should have correct name"):
		return false
	return true

func test_card_play_basic():
	"""Test basic card playing functionality"""
	var card: CardData = createCardFromName("goblin pair", GameZone.e.HAND_PLAYER)
	setPlayerGold(3)
	await test_runner.get_tree().process_frame
	if not assertCardCount(0, "play"):
		return false
	if not assertCardCount(1, "hand"):
		return false
	
	await game.tryPlayCard(card, GameZone.e.BATTLEFIELD_PLAYER)
	
	if not assertCardCount(2, "play"):
		return false
	if not assertCardCount(0, "hand"):
		return false
	if not assertCardExists("Goblin pair", "play"):
		return false

func test_insufficient_gold():
	"""Test that cards can't be played without enough gold"""
	var card: CardData = createCardFromName("goblin pair", GameZone.e.HAND_PLAYER) 
	setPlayerGold(0)  # Not enough to pay 1 gold cost
	
	# Verify gold is actually 0 before attempting to play
	var gold_before = game.game_data.player_gold.getValue()
	print("🪙 Gold before tryPlayCard: ", gold_before)
	if not assert_test_equal(gold_before, 0, "Gold should be 0 before play attempt"):
		return false
	
	await game.tryPlayCard(card, GameZone.e.BATTLEFIELD_PLAYER)
	
	# Card should still be in hand (payment should have failed)
	if not assertCardCount(0, "play"):
		return false
	if not assertCardCount(1, "hand"):
		return false
	
	# Verify gold is still 0 (no payment occurred)
	var gold_after = game.game_data.player_gold.getValue()
	if not assert_test_equal(gold_after, 0, "Gold should still be 0 after failed payment"):
		return false

func test_goblin_pair():
	"""Test Goblin Pair card creation and spawning"""
	var c: CardData = createCardFromName("goblin pair", GameZone.e.HAND_PLAYER)
	game.game_data.player_gold.setValue(99)
	await game.tryPlayCard(c, GameZone.e.BATTLEFIELD_PLAYER)
	var cardsInPlay = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	if not assert_test_equal(cardsInPlay.size(), 2, "Goblin Pair should spawn 2 cards"):
		return false

func test_card_loader():
	var card = CardLoaderAL.getCardByName("Goblin Kid")
	if not assert_test_true(card.cardName == "Goblin Kid", "Card load issue"):
		return false
	card = CardLoaderAL.getCardByName("goblin")
	if not assert_test_true(card.cardName == "goblin", "Token load issue"):
		return false
	card = CardLoaderAL.getCardByName("Goblin Boss")
	if not assert_test_true(card.cardName == "Goblin Boss", "Legendary load issue"):
		return false
	card = CardLoaderAL.getCardByName("Opp1")
	if not assert_test_true(card.cardName == "Opp1", "Opponent card load issue"):
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



func test_combat_location_independence():
	"""Test that attacking one combat location doesn't affect another location's state"""
	# Setup: Create two simple goblin cards
	var goblin1: CardData = createCardFromName("goblin", GameZone.e.HAND_PLAYER)
	var goblin2: CardData = createCardFromName("goblin", GameZone.e.HAND_PLAYER)
	
	# Get two different combat zones
	var combat_zone_1 = game.game_view.combat_zones[0] as CombatZone
	var combat_zone_2 = game.game_view.combat_zones[1] as CombatZone
	if not assert_test(combat_zone_1 != combat_zone_2, "Should have different combat zones"):
		return false
	
	# Play goblin1 to first combat location
	await game.tryPlayCard(goblin1, GameZone.e.COMBAT_PLAYER_1)
	
	# Play goblin2 to second combat location
	await game.tryPlayCard(goblin2, GameZone.e.COMBAT_PLAYER_2)
	
	# Verify both cards are assigned to their respective combat zones (DATA LAYER)
	var goblin1_zone = game.game_data.get_card_zone(goblin1)
	var goblin2_zone = game.game_data.get_card_zone(goblin2)
	
	if not assert_test_equal(goblin1_zone, GameZone.e.COMBAT_PLAYER_1, "Goblin1 should be in combat zone 1"):
		return false
	if not assert_test_equal(goblin2_zone, GameZone.e.COMBAT_PLAYER_2, "Goblin2 should be in combat zone 2"):
		return false
	
	# Verify cards are at index 0 in their respective zones (first card added)
	var goblin1_index = game.game_data.get_card_combat_index(goblin1)
	var goblin2_index = game.game_data.get_card_combat_index(goblin2)
	if not assert_test_equal(goblin1_index, 0, "Goblin1 should be at index 0"):
		return false
	if not assert_test_equal(goblin2_index, 0, "Goblin2 should be at index 0"):
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
	
	# Verify only the first combat zone was resolved (DATA LAYER)
	if not assert_test_true(game.game_data.is_combat_resolved(combat_zone_1), "Combat zone 1 should be resolved after clicking its button"):
		return false
	if not assert_test_false(game.game_data.is_combat_resolved(combat_zone_2), "Combat zone 2 should remain unresolved"):
		return false
	
	# Verify that the second combat zone's data in GameData hasn't changed
	var final_zone_2_data = game.game_data.get_combat_zone_data(combat_zone_2)
	if not assert_test_equal(final_zone_2_data.player_capture_current, initial_player_capture_current, 
		"Second combat zone's player_capture_current should not have changed"):
		return false

func test_bolt_spell_with_valid_target():
	"""Test casting Bolt spell with a legal target - bolt and target should end up in graveyard"""
	# Setup: Create Bolt spell and a target creature
	var bolt_card: CardData = createCardFromName("Bolt", GameZone.e.HAND_PLAYER)
	var target_creature: CardData = createCardFromName("goblin", GameZone.e.BATTLEFIELD_PLAYER)
	
	setPlayerGold(99)
	
	# Prepare selection data with the target creature
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	
	# Cast Bolt targeting the creature
	await game.tryPlayCard(bolt_card, GameZone.e.BATTLEFIELD_PLAYER, selections)
	
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
	var bolt_card = createCardFromName("Bolt", GameZone.e.HAND_PLAYER)
	var target_creature = createCardFromName("goblin", GameZone.e.BATTLEFIELD_PLAYER)
	
	setPlayerGold(99)
	
	# Prepare selection data showing cancellation
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	selections.cancelled = true
	
	# Find Bolt in hand data
	var bolt_card_data = null
	for card_data in game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER):
		if card_data.cardName == "Bolt":
			bolt_card_data = card_data
			break
	
	if not assert_test_not_null(bolt_card_data, "Bolt should be in hand before casting"):
		return false
	
	# Attempt to cast Bolt but cancel
	await game.tryPlayCard(bolt_card, GameZone.e.BATTLEFIELD_PLAYER, selections)
	
	# Wait a frame for any reparenting to complete
	await test_runner.get_tree().process_frame
	
	# Check what cards are actually in hand (data layer)
	for card_data in game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER):
		print("  - ", card_data.cardName)
	
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
	var bolt_card = createCardFromName("Bolt", GameZone.e.HAND_PLAYER)
	setPlayerGold(99)
	
	# Attempt to cast Bolt with no targets available
	await game.tryPlayCard(bolt_card, GameZone.e.BATTLEFIELD_PLAYER)
	
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
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	
	# Draw one card from player deck
	await game.drawCard(1, true)
	
	# Verify hand increased by one
	if not assertCardCount(initial_hand_count + 1, "hand"):
		return false
	
	# Get the newly drawn card data (last card in hand data)
	var drawn_card_data = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER)[-1]
	if not assert_test_not_null(drawn_card_data, "Should have drawn a card"):
		return false
	
	# Verify the card is player controlled
	if not assert_test_true(drawn_card_data.playerControlled, "Drawn card should be player controlled"):
		return false
	
	# Verify the card is player owned
	if not assert_test_true(drawn_card_data.playerOwned, "Drawn card should be player owned"):
		return false
	
	return true

func test_deck_card_opponent_control():
	"""Test that cards drawn from opponent deck have correct opponent control"""
	# Add a card to opponent deck
	var test_card_data = CardLoaderAL.getCardByName("Goblin")
	addCardToDeck(test_card_data, false)  # Add to opponent deck
	
	# Get initial opponent hand count
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_OPPONENT).size()
	
	# Draw one card from opponent deck
	await game.drawCard(1, false)
	
	# Verify opponent hand increased by one
	var actual_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_OPPONENT).size()
	if not assert_test_equal(actual_hand_count, initial_hand_count + 1, "Opponent hand should increase by one"):
		return false
	
	# Get the newly drawn card data (last card in opponent hand data)
	var drawn_card_data = game.game_data.get_cards_in_zone(GameZone.e.HAND_OPPONENT)[-1]
	if not assert_test_not_null(drawn_card_data, "Should have drawn a card to opponent hand"):
		return false
	
	# Verify the card is NOT player controlled
	if not assert_test_false(drawn_card_data.playerControlled, "Drawn card should NOT be player controlled"):
		return false
	
	# Verify the card is NOT player owned
	if not assert_test_false(drawn_card_data.playerOwned, "Drawn card should NOT be player owned"):
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
	
	# Get the drawn card data (last card in hand)
	var drawn_card_data = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER)[-1]
	if not assert_test_not_null(drawn_card_data, "Should have drawn a card"):
		return false
	
	# Verify the card is player controlled before playing
	if not assert_test_true(drawn_card_data.playerControlled, "Drawn card should be player controlled"):
		return false
	
	# Play the card using data layer (no view dependency)
	var play_success = await play_card_from_data(drawn_card_data, GameZone.e.HAND_PLAYER, true)
	if not assert_test_true(play_success, "Should successfully play the card"):
		return false
	
	# Verify gold was deducted from player gold
	var final_gold = game.game_data.player_gold.getValue()
	var expected_gold = initial_gold - drawn_card_data.goldCost
	if not assert_test_equal(final_gold, expected_gold, "Player gold should decrease by card cost"):
		return false
	
	return true

func test_deck_draw_order():
	"""Test that cards are drawn from the top of the deck (index 0) in correct order"""
	# Clear deck first to ensure clean test
	game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER).clear()
	
	# Add three different cards to deck in specific order
	var card1_data = CardLoaderAL.getCardByName("Goblin")
	var card2_data = CardLoaderAL.getCardByName("Goblin Pair") 
	var card3_data = CardLoaderAL.getCardByName("Bolt")
	
	# Add cards to deck using helper method - card1 should be at index 0 (top), card3 at index 2 (bottom)
	addCardToDeck(card1_data, true)  # Index 0 - should be drawn first
	addCardToDeck(card2_data, true)  # Index 1 - should be drawn second
	addCardToDeck(card3_data, true)  # Index 2 - should be drawn third
	
	# Verify deck has 3 cards
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER).size(), 3, "Deck should have 3 cards"):
		return false
	
	# Verify the top card (index 0) is Goblin
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER)[0].cardName, "goblin", "Top card should be Goblin"):
		return false
	
	# Draw one card
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	await game.drawCard(1, true)
	
	# Verify hand increased by one
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size(), initial_hand_count + 1, "Hand should increase by 1"):
		return false
	
	# Get the drawn card data (last card in hand data)
	var drawn_card_data = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER)[-1]
	if not assert_test_not_null(drawn_card_data, "Should have drawn a card"):
		return false
		
	if not assert_test_true(drawn_card_data.playerControlled, "Card should be player controlled"):
		return false
	
	# Verify the drawn card is the Goblin (was at index 0)
	if not assert_test_equal(drawn_card_data.cardName, "goblin", "Drawn card should be Goblin (from top of deck)"):
		return false
	
	# Verify the new top card (index 0) is now Goblin Pair (was index 1)
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER)[0].cardName, "Goblin pair", "New top card should be Goblin Pair"):
		return false
	
	# Verify the remaining bottom card (index 1) is Bolt (was index 2)
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER)[1].cardName, "Bolt", "Bottom card should be Bolt"):
		return false
	
	return true

func test_replace_mechanism() -> bool:
	"""Test Replace keyword parsing and cost calculation"""
	
	# Create a mock Punglynd Drengr card with Replace
	var drengr_card: CardData = createCardFromName("Punglynd Drengr", GameZone.e.HAND_PLAYER)
	
	# Verify Replace was parsed correctly
	if not assert_test(drengr_card.additionalCosts.size() > 0, "Drengr should have additional costs"):
		return false
	
	var replace_cost = null
	for cost in drengr_card.additionalCosts:
		if cost.get("cost_type") == "Replace":
			replace_cost = cost
			break
	
	if not assert_test(replace_cost != null, "Should find Replace cost data"):
		return false
	
	if not assert_test(replace_cost.get("valid_card") == "Card.YouCtrl+Cost.1+Creature", "Should parse ValidCard$ correctly"):
		return false
	
	if not assert_test(replace_cost.get("valid_card_alt") == "Card.YouCtrl+Cost.1+Grown-up", "Should parse ValidCardAlt$ correctly"):
		return false
	
	if not assert_test(replace_cost.get("add_reduction") == 1, "Should parse AddReduction correctly"):
		return false
	
	# Test hasReplaceOption when no valid targets
	if not assert_test(not CardPaymentManagerAL.hasReplaceOption(drengr_card), "Should not have Replace option with no valid targets"):
		return false
	
	# Create a valid target (1-cost creature)
	var target_creature = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	if not assert_test_not_null(target_creature, "Should be able to create Punglynd Child card"):
		return false
	
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
	var drengr_card = createCardFromName("Punglynd Drengr", GameZone.e.HAND_PLAYER)
	
	# Get Replace cost data
	var replace_cost = null
	for cost in drengr_card.additionalCosts:
		if cost.get("cost_type") == "Replace":
			replace_cost = cost
			break
	
	if not assert_test(replace_cost != null, "Should find Replace cost data"):
		return false
	
	# Create a Grown-up target for extra reduction
	var grownup_target = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	grownup_target.addSubtype("Grown-up")
	
	# Test cost calculation with Grown-up (should get additional reduction)
	var replace_cost_grownup = CardPaymentManagerAL.calculateReplaceCost(drengr_card, grownup_target)
	if not assert_test_equal(replace_cost_grownup, 1, "Replace cost with Grown-up should be 3-1-1=1"):
		return false
	
	# Test that getValidReplaceTargets finds the Grown-up target
	var valid_targets = CardPaymentManagerAL.getValidReplaceTargets(drengr_card, replace_cost)
	var found_grownup = false
	for target in valid_targets:
		if "Grown-up" in target.subtypes:
			found_grownup = true
			break
	
	if not assert_test(found_grownup, "Should find Grown-up target in valid targets"):
		return false
	
	print("✅ Replace with additional reduction test passed!")
	return true

func test_activated_ability_parsing() -> bool:
	"""Test parsing of activated abilities (AA:$)"""
	
	# Test with Punglynd Hersir's activated ability
	var hersir_card = createCardFromName("Punglynd Hersir", GameZone.e.HAND_PLAYER)
	
	# Check that the card has abilities
	if not assert_test(hersir_card.get_all_abilities().size() > 0, "Hersir should have abilities"):
		return false
	
	# Look for the activated ability
	var activated_ability = null
	for ability in hersir_card.activated_abilities:
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
	if not assert_test_equal(costs.size(), 1, "Should have 1 activation cost"):
		return false
	
	# Check sacrifice cost
	var sac_cost = null
	for cost in costs:
		if cost.get("type") == "Sacrifice":
			sac_cost = cost
	
	if not assert_test_not_null(sac_cost, "Should have sacrifice cost"):
		return false
	if not assert_test_equal(sac_cost.get("target"), "Self", "Sacrifice target should be Self"):
		return false
	
	# Test target conditions (stored in targeting_requirements for ActivatedAbility)
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
	
	# Create a test creature (try Tap Test Creature first, fallback to any creature)
	var test_card = createCardFromName("Punglynd Hersir", GameZone.e.HAND_PLAYER)
	
	# Add it to player base using proper game flow
	var dest_zone = GameZone.e.BATTLEFIELD_PLAYER if test_card.playerControlled else GameZone.e.BATTLEFIELD_OPPONENT
	await game.execute_move_card(test_card, dest_zone)
	await game.resolveStateBasedAction()
	
	# Test 1: Card should start untapped
	if not assert_test_false(test_card.is_tapped(), "Card should start untapped"):
		return false
	if not assert_test_true(test_card.can_tap(), "Card should be able to tap initially"):
		return false
	
	# Test 2: Test tapping manually
	test_card.tap()
	if not assert_test_true(test_card.is_tapped(), "Card should be tapped after tap()"):
		return false
	if not assert_test_false(test_card.can_tap(), "Card should not be able to tap when already tapped"):
		return false
	
	# Test 3: Test untapping
	test_card.untap()
	if not assert_test_false(test_card.is_tapped(), "Card should be untapped after untap()"):
		return false
	if not assert_test_true(test_card.can_tap(), "Card should be able to tap after untapping"):
		return false
	
	# Test 4: Test movement tapping (assuming we can move to combat)
	var combat_zone = game.game_view.combat_zones[0] as CombatZone
	
	# Try to move card to combat zone (should tap it)
	# After GridContainer3D refactor, we pass the CombatZone directly
	await game.tryMoveCard(test_card, combat_zone)
	
	# Check data layer: card should be in combat zone
	var card_zone = game.game_data.get_card_zone(test_card)
	if assert_test_true(GameZone.is_combat_zone(card_zone), "Movement to combat should succeed (DATA LAYER)"):
		if not assert_test_true(test_card.is_tapped(), "Card should be tapped after moving to combat"):
			return false
		
		var initial_zone = card_zone
		var initial_index = game.game_data.get_card_combat_index(test_card)
		
		# Try to move again (should fail because card is tapped)
		await game.tryMoveCard(test_card, combat_zone)
		var final_zone = game.game_data.get_card_zone(test_card)
		var final_index = game.game_data.get_card_combat_index(test_card)
		if not assert_test_equal(final_zone, initial_zone, "Card should remain in same zone (tapped cards can't move - DATA LAYER)"):
			return false
		if not assert_test_equal(final_index, initial_index, "Card should remain at same index (tapped cards can't move - DATA LAYER)"):
			return false
	
	# Test 5: Test activated ability with tap cost
	# First untap the card
	test_card.untap()
	setPlayerGold(10)  # Give plenty of mana
	
	# Find activated abilities with tap cost
	var tap_abilities = []
	for ability in test_card.activated_abilities:
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
			if not assert_test_true(test_card.is_tapped(), "Card should be tapped after using tap ability"):
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
	var hersir_card = createCardFromName("Punglynd Hersir", GameZone.e.BATTLEFIELD_PLAYER)
	
	var target_card = createCardFromName("Goblin", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 3: Verify target doesn't have Spellshield initially
	var has_spellshield_initial = target_card.has_keyword("Spellshield")
	
	if not assert_test_false(has_spellshield_initial, "Target should not have Spellshield initially"):
		return false
	
	# Step 4: Set up resources and activate Hersir's ability
	setPlayerGold(10)  # Plenty of mana
	
	# Find the activated ability
	var activated_ability = null
	for ability in hersir_card.activated_abilities:
		activated_ability = ability
		break
	
	if not assert_test_not_null(activated_ability, "Hersir should have activated ability"):
		return false

	# Provide explicit preselected targets for the effect.
	activated_ability.effect_parameters["Targets"] = [target_card]
	
	# Step 5: Activate the ability (sacrifices Hersir, grants Spellshield to all creatures)
	print("🎯 Activating Hersir's ability to grant Spellshield...")
	await AbilityManagerAL.activateAbility(hersir_card, activated_ability, game)
	await test_runner.get_tree().process_frame
	
	# Step 6: Verify target now has Spellshield
	var has_spellshield_after = target_card.has_keyword("Spellshield")
	
	if not assert_test_true(has_spellshield_after, "Target should have Spellshield after activation"):
		return false
	
	# Step 7: Verify the effect is tracked on the card itself
	if not assert_test_true(target_card.has_temporary_effects(), "Target card should have temporary effects tracked"):
		return false
	
	if not assert_test_true(target_card.has_temporary_effect(EffectType.Type.ADD_KEYWORD), "Target card should have ADD_KEYWORD temporary effect"):
		return false
	
	var card_temp_effects = target_card.get_temporary_effects_by_duration(TemporaryEffect.Duration.END_OF_TURN)
	if not assert_test_equal(card_temp_effects.size(), 1, "Should have 1 end-of-turn effect on card"):
		return false
	
	print("  ℹ️ ", target_card.temporary_effects.size(), " temporary effect(s) tracked on card")
	
	# Step 8: Trigger end of turn to clean up temporary effects
	print("🔄 Starting new turn to trigger cleanup...")
	await game.onTurnStart()
	await test_runner.get_tree().process_frame
	
	# Step 9: Verify Spellshield was removed
	var has_spellshield_after_turn = target_card.has_keyword("Spellshield")
	
	if not assert_test_false(has_spellshield_after_turn, "Target should not have Spellshield after end of turn"):
		return false
	
	# Step 10: Verify the effect was removed from the card's tracking
	if not assert_test_false(target_card.has_temporary_effects(), "Target card should have no temporary effects after cleanup"):
		return false
	
	if not assert_test_false(target_card.has_temporary_effect(EffectType.Type.ADD_KEYWORD), "Target card should not have ADD_KEYWORD temporary effect after cleanup"):
		return false
	
	print("✅ Temporary keyword effects test passed!")
	return true

func test_growth_spell_pump() -> bool:
	"""Test Growth spell - pump effect that gives +3 power until end of turn"""
	print("=== Testing Growth Spell (Pump Effect) ===")
	
	# Step 1: Create Growth spell and a target creature
	var growth_card = createCardFromName("Growth", GameZone.e.HAND_PLAYER)
	
	var target_creature: CardData = createCardFromName("Goblin", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 2: Place target in play and spell in hand
	setPlayerGold(10)
	
	# Step 3: Record initial power
	var initial_power = target_creature.power
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	
	await game.tryPlayCard(growth_card, GameZone.e.BATTLEFIELD_PLAYER, selections)
	await test_runner.get_tree().process_frame
	
	# Step 5: Verify power was increased by 3
	var boosted_power = target_creature.power
	if not assert_test_equal(boosted_power, initial_power + 3, "Power should be increased by 3"):
		return false
	
	# Step 6: Verify temporary effect is tracked
	if not assert_test_true(target_creature.has_temporary_effects(), "Should have temporary effect"):
		return false
	
	if not assert_test_true(target_creature.has_temporary_effect(EffectType.Type.PUMP), "Should have temporary PUMP effect"):
		return false
	
	var temp_effects = target_creature.get_temporary_effects_by_duration(TemporaryEffect.Duration.END_OF_TURN)
	if not assert_test_equal(temp_effects.size(), 1, "Should have 1 end-of-turn effect"):
		return false
	
	# Step 7: Verify Growth spell went to graveyard
	if not assertCardExists("Growth", "graveyard"):
		return false
	
	# Step 8: End turn to trigger cleanup
	print("🔄 Ending turn to test power boost removal...")
	await game.onTurnStart()
	await test_runner.get_tree().process_frame
	
	# Step 9: Verify power returned to original value
	var final_power = target_creature.power
	if not assert_test_equal(final_power, initial_power, "Power should return to original after end of turn"):
		return false
	
	print("  Final power after cleanup: ", final_power)
	
	# Step 10: Verify temporary effect was removed
	if not assert_test_false(target_creature.has_temporary_effects(), "Should have no temporary effects after cleanup"):
		return false
	
	if not assert_test_false(target_creature.has_temporary_effect(EffectType.Type.PUMP), "Should have no PUMP effect after cleanup"):
		return false
	
	print("✅ Growth spell pump effect test passed!")
	return true

func test_punglynd_child_growup():
	"""Test that Punglynd Child gains 'Grown-up' subtype after attacking and passing turn"""
	
	# Step 1: Create Punglynd Child token
	var child_card = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 3: Verify initial state - should not have Grown-up subtype yet
	if not assert_test_false("Grown-up" in child_card.subtypes, "Child should not have Grown-up subtype initially"):
		return false
	
	# Step 4: Make the child attack by moving it to a combat zone and resolving combat
	var combat_zone = game.game_view.combat_zones[0] as CombatZone
	
	# Move to combat zone (pass CombatZone directly after GridContainer3D refactor)
	await game.tryMoveCard(child_card, combat_zone)
	
	# Resolve combat to mark the card as having attacked
	await clickCombatButton(combat_zone)
	
	# Step 5: Verify the card attacked this turn
	if not assert_test_true(child_card.hasAttackedThisTurn, "Child should be marked as having attacked this turn"):
		return false
	
	# Step 6: Start new turn to trigger end-of-turn phase (simulates real game flow)
	await game.onTurnStart()
	
	# Step 7: Verify the child now has the Grown-up subtype
	if not assert_test_true("Grown-up" in child_card.subtypes, "Child should have Grown-up subtype after attacking and end-of-turn trigger"):
		return false
	
	print("✅ Punglynd Child grow-up test passed!")
	return true

func test_replace_with_insufficient_gold() -> bool:
	"""Test that Replace mechanism allows playing cards when player has insufficient gold but valid targets"""
	setPlayerGold(0)
	
	# Step 2: Create a Punglynd Child token in player base
	var child_card = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	child_card.addSubtype("Grown-up")
	
	# Step 3: Create Punglynd Childbearer and add to hand
	var childbearer_card = createCardFromName("Punglynd Childbearer", GameZone.e.HAND_PLAYER)
	
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
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	var initial_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	# Step 8: Use pre-selection system to specify Replace target
	print("🎮 Starting card play with Replace mechanism using pre-selection...")
	
	var selections = SelectionManager.CardPlaySelections.new()
	selections.set_replace_target(child_card)
	
	# Step 9: Try to play the card using Replace with pre-selections
	await game.tryPlayCard(childbearer_card, GameZone.e.BATTLEFIELD_PLAYER, selections)
	print("✅ Card play with Replace completed")
	await test_runner.get_tree().process_frame
	var final_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	var final_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	if not assert_test_equal(final_hand_count, initial_hand_count - 1, "Hand count should decrease by 1"):
		return false
	
	if not assert_test_equal(final_base_count, initial_base_count + 1, "Base count should increase by 1 (child replaced by childbearer who creates a token)"):
		return false
	
	# Step 10: Verify the Childbearer is now in play
	var cards_in_base = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	var childbearer_in_play = false
	for card_data in cards_in_base:
		if card_data.cardName == "Punglynd Childbearer":
			childbearer_in_play = true
			break
	
	if not assert_test_true(childbearer_in_play, "Punglynd Childbearer should be in play"):
		return false
	
	# Step 11: Verify player still has 0 gold (Replace cost was 0)
	if not assert_test_equal(game.game_data.player_gold.getValue(), 0, "Player should still have 0 gold after Replace"):
		return false
	
	# Step 12: Verify the original child is no longer in play (was replaced)
	var child_still_in_play = false
	for card_data in cards_in_base:
		if card_data == child_card:
			child_still_in_play = true
			break
	
	if not assert_test_false(child_still_in_play, "Original Punglynd Child should no longer be in play"):
		return false
	
	return true



func test_eyepatch_cast_from_deck():
	"""Test Eyepatch the Pirate casting itself from deck when another goblin enters play"""
	
	# Step 1: Get Eyepatch card data and add it to deck
	createCardFromName("Eyepatch the Pirate", GameZone.e.DECK_PLAYER)
	# Step 2: Give player gold and create a goblin token to play
	setPlayerGold(10)
	var goblin_token = createCardFromName("Goblin", GameZone.e.HAND_PLAYER)
	
	# Step 3: Count cards in play before
	var initial_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	# Step 4: Play the goblin token - this should trigger Eyepatch from deck
	await game.tryPlayCard(goblin_token, GameZone.e.BATTLEFIELD_PLAYER)
	
	# Wait for trigger resolution
	await test_runner.get_tree().create_timer(0.5).timeout
	
	# Step 5: Verify Eyepatch is no longer in deck
	var eyepatch_in_deck = game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER).any(func(card): return card.cardName == "Eyepatch the Pirate")
	if not assert_test_false(eyepatch_in_deck, "Eyepatch should have been removed from deck"):
		return false
	
	# Step 6: Verify Eyepatch is now on battlefield
	var cards_in_play = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	var eyepatch_in_play = cards_in_play.any(func(card_data): return card_data.cardName == "Eyepatch the Pirate")
	if not assert_test_true(eyepatch_in_play, "Eyepatch should be on battlefield"):
		return false
	
	# Step 7: Verify both cards are in play (Goblin + Eyepatch)
	var final_base_count = cards_in_play.size()
	if not assert_test_equal(final_base_count, initial_base_count + 2, "Should have 2 new cards (Goblin + Eyepatch)"):
		return false
	return true

func test_goblin_emblem_replacement_effect():
	"""Test Goblin Emblem replacement effect - creating extra tokens, then removing effect when destroyed"""
	
	# Step 1: Give player plenty of gold
	setPlayerGold(99)
	
	# Step 2: Create and play Goblin Emblem (capture reference)
	var goblin_emblem = createCardFromName("Goblin Emblem", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 3: Create and play first Goblin Pair
	var goblin_pair_1 = createCardFromName("Goblin pair", GameZone.e.HAND_PLAYER)
	
	await game.tryPlayCard(goblin_pair_1, GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 4: Count all cards in play
	var all_cards = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	var total_cards = all_cards.size()
	# Step 5: Count Goblin tokens specifically
	var goblin_tokens = all_cards.filter(func(card_data): 
		return card_data.cardName.to_lower() == "goblin" and card_data.isToken
	)
	var token_count = goblin_tokens.size()
	
	print("📊 Goblin tokens created (with emblem): ", token_count)
	
	# Step 6: Verify 2 Goblin tokens were created (1 base + 1 from replacement effect)
	if not assert_test_equal(token_count, 2, "Should have created 2 Goblin tokens (1 base + 1 from Goblin Emblem)"):
		return false
	print("✅ Correct number of tokens created with emblem active")
	
	# Step 7: Verify total cards (Goblin Emblem + Goblin Pair + 2 Goblin tokens = 4)
	if not assert_test_equal(total_cards, 4, "Should have Goblin Emblem + Goblin Pair + 2 tokens"):
		return false
	
	# Step 8: Destroy the Goblin Emblem (move to graveyard)
	print("🗑️ Destroying Goblin Emblem...")
	await game.execute_move_card(goblin_emblem, GameZone.e.GRAVEYARD_PLAYER)
	await test_runner.get_tree().process_frame
	
	# Step 9: Verify Goblin Emblem is in graveyard
	var emblem_in_graveyard = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).has(goblin_emblem)
	if not assert_test_true(emblem_in_graveyard, "Goblin Emblem should be in graveyard"):
		return false
	print("✅ Goblin Emblem moved to graveyard")
	
	# Step 10: Play a second Goblin Pair
	print("🃏 Playing second Goblin Pair without emblem...")
	var goblin_pair_2 = createCardFromName("Goblin pair", GameZone.e.HAND_PLAYER)
	await game.tryPlayCard(goblin_pair_2, GameZone.e.BATTLEFIELD_PLAYER)
	await test_runner.get_tree().process_frame
	
	# Step 11: Count Goblin tokens again (should only have 1 more, not 2)
	var all_cards_after = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	var goblin_tokens_after = all_cards_after.filter(func(card_data): 
		return card_data.cardName.to_lower() == "goblin" and card_data.isToken
	)
	var token_count_after = goblin_tokens_after.size()
	
	print("📊 Total Goblin tokens after second pair: ", token_count_after)
	
	# Step 12: Verify only 3 total Goblin tokens (2 from first pair + 1 from second pair)
	if not assert_test_equal(token_count_after, 3, "Should have 3 total Goblin tokens (2 from first + 1 from second, no replacement effect)"):
		return false
	print("✅ Correct - only 1 additional token created without emblem")
	
	print("✅ Goblin Emblem replacement effect test passed!")
	return true

func test_activated_ability_sacrifice_controller_filter() -> bool:
	"""Test activated ability sacrifice costs only count cards controlled by the same controller"""
	var source_card = CardData.new()
	source_card.cardName = "Test Sacrifice Source"
	source_card.playerControlled = true
	source_card.playerOwned = true
	source_card.addType(CardData.CardType.CREATURE)
	game.game_data.add_card_to_zone(source_card, GameZone.e.BATTLEFIELD_PLAYER)

	var activated_ability = ActivatedAbility.new(source_card, EffectType.Type.DRAW)
	activated_ability.with_activation_cost({
		"type": "Sacrifice",
		"target": "Creature",
		"count": 1
	})
	source_card.activated_abilities.append(activated_ability)

	if not assert_test_true(CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card), "Should be able to pay sacrifice cost with the source creature in play"):
		return false

	var opponent_card = CardData.new()
	opponent_card.cardName = "Opponent Sacrifice Fodder"
	opponent_card.playerControlled = false
	opponent_card.playerOwned = false
	opponent_card.addType(CardData.CardType.CREATURE)
	game.game_data.add_card_to_zone(opponent_card, GameZone.e.BATTLEFIELD_OPPONENT)

	activated_ability.activation_costs[0]["count"] = 2
	if not assert_test_false(CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card), "Should not count opponent creatures toward sacrifice costs"):
		return false

	var ally_card = CardData.new()
	ally_card.cardName = "Ally Sacrifice Fodder"
	ally_card.playerControlled = true
	ally_card.playerOwned = true
	ally_card.addType(CardData.CardType.CREATURE)
	game.game_data.add_card_to_zone(ally_card, GameZone.e.BATTLEFIELD_PLAYER)

	if not assert_test_true(CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card), "Should be able to pay sacrifice cost with two player-controlled creatures"):
		return false

	activated_ability.activation_costs[0]["target"] = "Creature.TestSacrificeType"
	if not assert_test_false(CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card), "Should not be able to pay subtype-restricted sacrifice cost with no matching creatures"):
		return false

	ally_card.addSubtype("TestSacrificeType")
	if not assert_test_false(CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card), "Should still fail when only one player-controlled creature matches the subtype"):
		return false

	source_card.addSubtype("TestSacrificeType")
	if not assert_test_true(CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card), "Should be able to pay subtype-restricted sacrifice cost when both player-controlled creatures match"):
		return false

	return true

func test_warcamp_activated_ability() -> bool:
	"""Test Punglynd Warcamp's activated ability with tap and sacrifice cost"""
	
	# Step 1: Create Warcamp card in play
	var warcamp_card = createCardFromName("Punglynd Warcamp", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 2: Create Punglynd Child token in play (without Grown-up subtype initially)
	var child_card:CardData = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	
	# Step 3: Add Goblin Pair to deck
	game.game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER).clear()
	var goblin_pair_data:CardData = createCardFromName("Goblin Pair", GameZone.e.DECK_PLAYER)
	
	# Step 4: Find Warcamp's activated ability
	var activated_ability = null
	if warcamp_card.activated_abilities.size() > 0:
		activated_ability=warcamp_card.activated_abilities[0]
	
	if not assert_test_not_null(activated_ability, "Warcamp should have activated ability"):
		return false
	
	# Verify the ability has the correct effect type (Draw)
	var effect_type_str = EffectType.type_to_string(activated_ability.effect_type)
	if not assert_test_equal(effect_type_str, "Draw", "Ability should be Draw effect"):
		return false
	
	# Step 5: Add Grown-up subtype to the child token
	child_card.addSubtype("Grown-up")
	await test_runner.get_tree().process_frame
	
	if not assert_test_true("Grown-up" in child_card.subtypes, "Child should have Grown-up subtype now"):
		return false
	
	# Step 6: Verify ability can be activated
	var can_pay = CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, warcamp_card)
	if not assert_test_true(can_pay, "Should be able to activate ability with valid sacrifice target"):
		return false
	
	# Step 7: Store initial state
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	var initial_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	# Verify warcamp is untapped
	if not assert_test_false(warcamp_card.is_tapped(), "Warcamp should be untapped"):
		return false
	
	# Step 8: Create pre-selection for the sacrifice (child token)
	var selections = SelectionManager.CardPlaySelections.new()
	selections.sacrifice_targets.push_back(child_card)
	
	# Activate the ability with pre-selections
	await AbilityManagerAL.activateAbility(warcamp_card, activated_ability, game, selections)
	await test_runner.get_tree().process_frame
	
	# Step 9: Verify warcamp is now tapped
	if not assert_test_true(warcamp_card.is_tapped(), "Warcamp should be tapped after activation"):
		return false
	
	# Step 10: Verify child was sacrificed (removed from play)
	var cards_in_base = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	var child_still_in_play = false
	for card_data in cards_in_base:
		if card_data == child_card:
			child_still_in_play = true
			break
	
	if not assert_test_false(child_still_in_play, "Child token should have been sacrificed"):
		return false
	
	# Step 11: Verify base count decreased by 1 (child removed)
	var final_base_count = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	if not assert_test_equal(final_base_count, initial_base_count - 1, "Base should have one less card"):
		return false
	
	# Step 12: Verify card was drawn (hand increased by 1)
	var final_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	if not assert_test_equal(final_hand_count, initial_hand_count + 1, "Hand should increase by 1"):
		return false
	return true

func test_move_effect() -> bool:
	"""Test the MoveCard effect - moves cards between zones"""
	
	# Step 1: Create a dummy card to put in player's graveyard
	var graveyard_card_data = CardData.new()
	graveyard_card_data.cardName = "GraveyardTarget"
	graveyard_card_data.addType(CardData.CardType.CREATURE)  # Must be a Creature to match filter
	graveyard_card_data.playerControlled = true
	graveyard_card_data.playerOwned = true
	game.game_data.add_card_to_zone(graveyard_card_data, GameZone.e.GRAVEYARD_PLAYER)
	
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size(), 1, "Player graveyard should have 1 card"):
		return false
	
	# Step 2: Create Grave Whisperer card (has Strike trigger with Move effect)
	# Create as opponent-controlled since it's an opponent card
	var grave_whisperer = createCardFromName("Grave Whisperer", GameZone.e.HAND_OPPONENT, false)
	game.game_data.opponent_gold.setValue(99)
	
	# Step 3: Add to hand first, then play it to trigger enter effects
	await game.tryPlayCard(grave_whisperer, GameZone.e.BATTLEFIELD_OPPONENT)
	
	# Wait for scene tree to update
	await test_runner.get_tree().process_frame
	
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_OPPONENT).size(), 1, "Should have 1 card in play"):
		return false
	
	# Step 4: Verify initial graveyard state
	var initial_player_graveyard = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size()
	var initial_opponent_graveyard = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_OPPONENT).size()
	
	if not assert_test_equal(initial_player_graveyard, 1, "Player graveyard should start with 1 card"):
		return false
	if not assert_test_equal(initial_opponent_graveyard, 0, "Opponent graveyard should start empty"):
		return false
	
	# Step 5: Move Grave Whisperer to combat zone slot to trigger Strike
	print("🎮 Moving Grave Whisperer to combat...")
	var combat_zone = game.game_view.combat_zones[0]  # Use first combat zone
	await game.execute_move_card(grave_whisperer, GameZone.e.COMBAT_OPPONENT_1)
	
	# Wait for movement to complete
	await test_runner.get_tree().process_frame
	
	# Step 6: Resolve combat to trigger the Strike ability
	print("🎮 Resolving combat to trigger Strike...")
	# Convert CombatZone to GameZone.e
	var zone_index = game.game_view.get_combat_zones().find(combat_zone)
	var combat_zone_enum := (GameZone.e.COMBAT_OPPONENT_1 + zone_index) as GameZone.e
	await game.resolve_combat_for_zone(combat_zone_enum)
	
	# Step 7: Verify card moved from player to opponent graveyard
	var final_player_graveyard = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size()
	var final_opponent_graveyard = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_OPPONENT).size()
	
	if not assert_test_equal(final_player_graveyard, 0, "Player graveyard should be empty"):
		return false
	print("✅ Player graveyard emptied")
	
	if not assert_test_equal(final_opponent_graveyard, 1, "Opponent graveyard should have 1 card"):
		return false
	print("✅ Card moved to opponent graveyard")
	
	# Step 8: Verify the moved card is correct
	var moved_card = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_OPPONENT)[0]
	if not assert_test_equal(moved_card.cardName, "GraveyardTarget", "Moved card should be GraveyardTarget"):
		return false
	print("✅ Correct card was moved")
	
	print("✅ Move effect test passed!")
	return true

func test_recycling_three_uses_per_turn():
	"""Test that cards can be recycled 3 times per turn with gold rewards and signal emissions"""
	
	# Step 1: Create 4 goblin cards in hand
	var card1 = createCardFromName("Goblin", GameZone.e.HAND_PLAYER)
	var card2 = createCardFromName("Goblin", GameZone.e.HAND_PLAYER)
	var card3 = createCardFromName("Goblin", GameZone.e.HAND_PLAYER)
	var card4 = createCardFromName("Goblin", GameZone.e.HAND_PLAYER)
	
	# Step 2: Verify initial setup
	if not assertCardCount(4, "hand"):
		return false
	
	# Step 3: Set up signal tracking (use Dictionary to capture by reference)
	var signal_data = {"count": 0}
	var signal_callback = func(card_data: CardData):
		signal_data["count"] += 1
		print("♻️ Signal emitted for: ", card_data.cardName)
	
	game.card_recycled.connect(signal_callback)
	
	# Step 4: Store initial gold
	var initial_gold = game.game_data.player_gold.getValue()
	print("💰 Initial gold: ", initial_gold)
	
	# Step 5: Recycle first card - should succeed
	print("\n--- Recycling Card 1 ---")
	var result1 = await game.recycle_card(card1)
	if not assert_test_true(result1, "First recycle should succeed"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify card 1 effects
	if not assertCardCount(3, "hand"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(game.game_data.player_gold.getValue(), initial_gold + 1, "Gold should increase by 1 after first recycle"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(signal_data["count"], 1, "Signal should have been emitted once"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(game.game_data.recycling_remaining.value, 2, "Should have 2 recycles remaining"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Step 6: Recycle second card - should succeed
	print("\n--- Recycling Card 2 ---")
	var result2 = await game.recycle_card(card2)
	if not assert_test_true(result2, "Second recycle should succeed"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify card 2 effects
	if not assertCardCount(2, "hand"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(game.game_data.player_gold.getValue(), initial_gold + 2, "Gold should increase by 2 total"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(signal_data["count"], 2, "Signal should have been emitted twice"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(game.game_data.recycling_remaining.value, 1, "Should have 1 recycle remaining"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Step 7: Recycle third card - should succeed
	print("\n--- Recycling Card 3 ---")
	var result3 = await game.recycle_card(card3)
	if not assert_test_true(result3, "Third recycle should succeed"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify card 3 effects
	if not assertCardCount(1, "hand"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(game.game_data.player_gold.getValue(), initial_gold + 3, "Gold should increase by 3 total"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(signal_data["count"], 3, "Signal should have been emitted three times"):
		game.card_recycled.disconnect(signal_callback)
		return false
	if not assert_test_equal(game.game_data.recycling_remaining.value, 0, "Should have 0 recycles remaining"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Step 8: Try to recycle fourth card - should FAIL (no uses remaining)
	print("\n--- Attempting to Recycle Card 4 (Should Fail) ---")
	var gold_before_fourth = game.game_data.player_gold.getValue()
	var result4 = await game.recycle_card(card4)
	
	if not assert_test_false(result4, "Fourth recycle should fail (no uses remaining)"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify card 4 stayed in hand
	if not assertCardCount(1, "hand"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify card 4 is still the same card
	var remaining_cards = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER)
	if not assert_test_equal(remaining_cards[0], card4, "The remaining card should be card4"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify gold did not increase
	if not assert_test_equal(game.game_data.player_gold.getValue(), gold_before_fourth, "Gold should not increase after failed recycle"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Verify signal was not emitted again
	if not assert_test_equal(signal_data["count"], 3, "Signal should still be 3 (not emitted for failed recycle)"):
		game.card_recycled.disconnect(signal_callback)
		return false
	
	# Cleanup
	game.card_recycled.disconnect(signal_callback)
	
	print("✅ Recycling three-uses-per-turn test passed!")
	return true

func test_elusive_position_swap() -> bool:
	"""Test that Elusive keyword causes position swap when another card enters the same combat zone"""
	print("=== Testing Elusive Position Swap ===")
	
	# Step 1: Create test card templates for Elusive testing
	var elusive_template = CardData.new()
	elusive_template.cardName = "Elusive Test Card"
	elusive_template.addType(CardData.CardType.CREATURE)
	elusive_template.power = 1
	elusive_template.goldCost = 1
	elusive_template.text_box = "Elusive"  # Keyword will be parsed by game.createCardData
	
	var regular_template_1 = CardData.new()
	regular_template_1.cardName = "Regular Card 1"
	regular_template_1.addType(CardData.CardType.CREATURE)
	regular_template_1.power = 2
	regular_template_1.goldCost = 1
	
	var regular_template_2 = CardData.new()
	regular_template_2.cardName = "Regular Card 2"
	regular_template_2.addType(CardData.CardType.CREATURE)
	regular_template_2.power = 3
	regular_template_2.goldCost = 1
	
	var dummy_template = CardData.new()
	dummy_template.cardName = "Dummy Card"
	dummy_template.addType(CardData.CardType.CREATURE)
	dummy_template.power = 1
	dummy_template.goldCost = 1
	
	# Step 2: Use game.createCardData to properly create cards with all abilities registered
	var elusive_card = game.createCardData(elusive_template, GameZone.e.BATTLEFIELD_PLAYER, true)
	var regular_card_1 = game.createCardData(regular_template_1, GameZone.e.BATTLEFIELD_PLAYER, true)
	var regular_card_2 = game.createCardData(regular_template_2, GameZone.e.BATTLEFIELD_PLAYER, true)
	var dummy_card = game.createCardData(dummy_template, GameZone.e.BATTLEFIELD_PLAYER, true)
	
	# Add Elusive ability using CardLoader (ensures test uses same logic as production code)
	# Note: _add_elusive_ability adds the ability but doesn't register it to game signals
	CardLoaderAL._add_elusive_ability(elusive_card)
	
	# Register the newly added ability to game signals (since createCardData already called subscribe_to_game_signals)
	if elusive_card.triggered_abilities.size() > 0:
		var new_ability = elusive_card.triggered_abilities[-1]
		new_ability.register_to_game(game)
	
	print("  ✅ Cards created at battlefield using game.createCardData")
	
	# Step 3: Move elusive and regular cards to combat zone 0
	var combat_zone_0 = game.game_view.combat_zones[0] as CombatZone
	await game.tryMoveCard(elusive_card, combat_zone_0)
	await test_runner.get_tree().process_frame
	await game.tryMoveCard(regular_card_1, combat_zone_0)
	await test_runner.get_tree().process_frame
	await game.tryMoveCard(regular_card_2, combat_zone_0)
	await test_runner.get_tree().process_frame
	
	# Step 3b: Move dummy card to combat zone 1 (different zone)
	var combat_zone_1 = game.game_view.combat_zones[1] as CombatZone
	await game.tryMoveCard(dummy_card, combat_zone_1)
	await test_runner.get_tree().process_frame
	
	# Step 4: Verify all cards in correct combat zones
	var elusive_zone = game.game_data.get_card_zone(elusive_card)
	if not assert_test_true(GameZone.is_combat_zone(elusive_zone), "Elusive card should be in combat zone"):
		return false
	
	# Step 5: Verify initial positions (Elusive should be first at index 0 in zone 0)
	var elusive_initial_index = game.game_data.get_card_combat_index(elusive_card)
	var regular_1_index = game.game_data.get_card_combat_index(regular_card_1)
	var regular_2_index = game.game_data.get_card_combat_index(regular_card_2)
	
	print("  📊 Initial positions in zone 0 - Elusive: %d, Regular 1: %d, Regular 2: %d" % [elusive_initial_index, regular_1_index, regular_2_index])
	
	if not assert_test_equal(elusive_initial_index, 0, "Elusive card should be at index 0 initially"):
		return false
	
	# Step 6: Resolve combat in zone 1 (different zone) - Elusive should NOT trigger
	print("  🎮 Resolving combat in zone 1 (Elusive should NOT trigger)...")
	var dummy_zone_enum = game.game_data.get_card_zone(dummy_card)
	await game.resolve_combat_for_zone(dummy_zone_enum)
	
	# Wait for trigger resolution
	await test_runner.get_tree().process_frame
	await test_runner.get_tree().process_frame
	
	# Step 7: Verify Elusive did NOT move (still at index 0)
	var elusive_after_zone_1 = game.game_data.get_card_combat_index(elusive_card)
	print("  📊 Position after zone 1 combat - Elusive: %d" % elusive_after_zone_1)
	
	if not assert_test_equal(elusive_after_zone_1, 0, "Elusive card should still be at index 0 after different zone combat"):
		return false
	
	print("  ✅ Elusive did not trigger for different combat zone")
	
	# Step 8: Resolve combat in zone 0 (where Elusive is) - Elusive SHOULD trigger
	print("  🎮 Resolving combat in zone 0 (Elusive SHOULD trigger)...")
	var elusive_zone_enum = game.game_data.get_card_zone(elusive_card)
	await game.resolve_combat_for_zone(elusive_zone_enum)
	
	# Wait for trigger resolution
	await test_runner.get_tree().process_frame
	await test_runner.get_tree().process_frame
	
	# Step 9: Verify Elusive moved to last position (index 2)
	var elusive_final_index = game.game_data.get_card_combat_index(elusive_card)
	var regular_1_final_index = game.game_data.get_card_combat_index(regular_card_1)
	var regular_2_final_index = game.game_data.get_card_combat_index(regular_card_2)
	
	print("  📊 Final positions after zone 0 combat - Elusive: %d, Regular 1: %d, Regular 2: %d" % [elusive_final_index, regular_1_final_index, regular_2_final_index])
	
	if not assert_test_equal(elusive_final_index, 2, "Elusive card should be at index 2 (last position) after its zone's combat"):
		return false
	
	print("  ✅ Elusive retreated to back position (index 2) in its own combat zone")
	print("✅ Elusive position swap test passed!")
	return true

func test_casting_condition() -> bool:
	"""Test casting conditions (CC:$) - card can only be cast when condition is met"""
	print("=== Testing Casting Condition System ===")
	
	# Step 1: Create a test card with a casting condition (YouCtrl+Grown-up)
	var test_card = CardData.new()
	test_card.cardName = "Test Conditional Spell"
	test_card.goldCost = 1
	test_card.addType(CardData.CardType.SPELL)
	test_card.addCastingCondition("YouCtrl+Grown-up")  # Can only cast if controlling a Grown-up
	test_card = game.createCardData(test_card, GameZone.e.HAND_PLAYER, true)
	
	if not assert_test_not_null(test_card, "Test card should be created"):
		return false
	
	# Step 2: Give player gold to ensure cost isn't the issue
	setPlayerGold(10)
	
	# Step 3: Create Punglynd Child in play (initially without Grown-up subtype)
	var child_card = createCardFromName("Punglynd Child", GameZone.e.BATTLEFIELD_PLAYER)
	if not assert_test_not_null(child_card, "Punglynd Child should be created"):
		return false
	
	# Step 4: Verify child doesn't have Grown-up subtype yet
	if not assert_test_false("Grown-up" in child_card.subtypes, "Child should not have Grown-up subtype initially"):
		return false
	
	# Step 5: Verify card CANNOT be cast (condition not met)
	var is_castable_before = CardPaymentManagerAL.isCardCastable(test_card)
	if not assert_test_false(is_castable_before, "Card should NOT be castable without Grown-up in play"):
		return false
	print("  ✅ Card correctly not castable when condition not met")
	
	# Step 6: Add Grown-up subtype to the child
	child_card.addSubtype("Grown-up")
	await test_runner.get_tree().process_frame  # Let the change propagate
	
	# Step 7: Verify child now has Grown-up subtype
	if not assert_test_true("Grown-up" in child_card.subtypes, "Child should have Grown-up subtype after adding it"):
		return false
	
	# Step 8: Verify card CAN NOW be cast (condition met)
	var is_castable_after = CardPaymentManagerAL.isCardCastable(test_card)
	if not assert_test_true(is_castable_after, "Card SHOULD be castable with Grown-up in play"):
		return false
	print("  ✅ Card correctly castable when condition is met")
	
	print("✅ Casting condition test passed!")
	return true

func test_fleeting_keyword() -> bool:
	"""Test fleeting keyword - card is discarded at end of turn if still in hand"""
	print("=== Testing Fleeting Keyword ===")
	
	# Step 1: Create a test card with fleeting keyword
	var test_card = CardData.new()
	test_card.cardName = "Test Fleeting Card"
	test_card.goldCost = 1
	test_card.addType(CardData.CardType.CREATURE)
	test_card.add_keyword("fleeting")  # Add the fleeting keyword
	
	# Step 2: Add fleeting ability using CardLoader (same as production code)
	CardLoaderAL._add_fleeting_ability(test_card)
	
	# Step 3: Create the card in hand and register it to game signals
	test_card = game.createCardData(test_card, GameZone.e.HAND_PLAYER, true)
	
	if not assert_test_not_null(test_card, "Test card should be created"):
		return false
	
	# Wait for card creation to complete
	await test_runner.get_tree().process_frame
	
	# Step 4: Verify card has fleeting keyword
	if not assert_test_true(test_card.has_keyword("fleeting"), "Card should have fleeting keyword"):
		return false
	
	# Step 5: Verify card has the fleeting triggered ability
	var has_fleeting_ability = false
	for ability in test_card.triggered_abilities:
		if ability.effect_type == EffectType.Type.MOVE_CARD:
			has_fleeting_ability = true
			break
	
	if not assert_test_true(has_fleeting_ability, "Card should have fleeting triggered ability"):
		return false
	
	# Step 6: Verify card is in hand
	var initial_hand_count = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).size()
	if not assert_test_true(initial_hand_count >= 1, "Card should be in hand"):
		return false
	
	var card_in_hand = game.game_data.get_cards_in_zone(GameZone.e.HAND_PLAYER).has(test_card)
	if not assert_test_true(card_in_hand, "Test card should be in hand"):
		return false
	print("  ✅ Card is in hand")
	
	# Step 7: Verify card is NOT in graveyard yet
	var initial_graveyard_count = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size()
	var card_in_graveyard_before = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).has(test_card)
	if not assert_test_false(card_in_graveyard_before, "Card should NOT be in graveyard yet"):
		return false
	
	# Step 8: End turn to trigger fleeting discard
	print("  🔄 Ending turn to trigger fleeting discard...")
	await game.onTurnStart()
	await test_runner.get_tree().process_frame
	await test_runner.get_tree().process_frame  # Extra frame for trigger resolution
	
	# Step 9: Verify card IS NOW in graveyard
	var card_in_graveyard_after = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).has(test_card)
	if not assert_test_true(card_in_graveyard_after, "Card SHOULD be in graveyard after turn end"):
		return false
	print("  ✅ Card moved to graveyard")
	
	print("✅ Fleeting keyword test passed!")
	return true

func test_delayed_effect_sacrifice() -> bool:
	"""Test delayed sacrifice effect at end of turn - creature should be sacrificed"""
	print("=== Testing Delayed Sacrifice at End of Turn ===")
	
	# Step 1: Create a creature in play
	var target_creature = createCardFromName("Goblin", GameZone.e.BATTLEFIELD_PLAYER)
	print("  📦 Created creature: ", target_creature.cardName)
	
	# Step 2: Create a spell with delayed sacrifice trigger at end of turn
	var spell_card = CardData.new()
	spell_card.cardName = "Test Delayed Sacrifice Spell"
	spell_card.goldCost = 0
	spell_card.addType(CardData.CardType.SPELL)
	
	# Create spell effect with pre-parsed CreateDelayedEffect parameters
	var spell_effect = {
		"effect_type": EffectType.Type.CREATE_DELAYED_EFFECT,
		"effect_parameters": {
			"TriggerEvent": TriggeredAbility.GameEventType.END_OF_TURN,  # Trigger at end of turn
			"NestedEffectType": EffectType.Type.SACRIFICE,  # Sacrifice effect
			"NestedParameters": {
				"TargetCard": target_creature  # Will be set when spell is cast with target
			}
		}
	}
	spell_card.spell_effects.append(spell_effect)
	
	# Add spell to hand
	spell_card = game.createCardData(spell_card, GameZone.e.HAND_PLAYER, true)
	
	# Step 3: Verify orphaned_abilities is empty initially
	if not assert_test_equal(game.orphaned_abilities.size(), 0, "Should have no orphaned abilities initially"):
		return false
	
	# Step 4: Verify creature is in battlefield
	if not assertCardExists("Goblin", "play"):
		return false
	
	# Step 5: Cast the spell with the creature as target
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	
	print("  🎯 Casting delayed sacrifice spell...")
	await game.tryPlayCard(spell_card, GameZone.e.BATTLEFIELD_PLAYER, selections)
	await test_runner.get_tree().process_frame
	
	# Step 6: Verify orphaned ability was created
	if not assert_test_equal(game.orphaned_abilities.size(), 1, "Should have 1 orphaned ability after casting"):
		return false
	print("  ✅ Orphaned ability created")
	
	# Step 7: Verify creature is still in play (hasn't been sacrificed yet)
	if not assertCardExists("Goblin", "play"):
		return false
	# Note: Spell card is now in graveyard, so we check that Goblin is NOT there
	var graveyard_cards = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER)
	var goblin_in_graveyard = false
	for card in graveyard_cards:
		if card.cardName.to_lower() == "goblin":
			goblin_in_graveyard = true
			break
	if not assert_test_false(goblin_in_graveyard, "Goblin should NOT be in graveyard yet"):
		return false
	print("  ✅ Creature still in play (not sacrificed yet)")
	
	# Step 8: End turn to trigger the delayed sacrifice
	print("  🔄 Ending turn to trigger sacrifice...")
	await game.onTurnStart()
	await test_runner.get_tree().process_frame
	await test_runner.get_tree().process_frame  # Extra frame for trigger resolution
	
	# Step 9: Verify creature was sacrificed (moved to graveyard)
	if not assertCardExists("Goblin", "graveyard"):
		return false
	if not assertCardCount(0, "play"):
		return false
	print("  ✅ Creature sacrificed and moved to graveyard")
	
	# Step 10: Verify orphaned ability was removed (one-shot)
	if not assert_test_equal(game.orphaned_abilities.size(), 0, "Orphaned ability should be removed after triggering"):
		return false
	print("  ✅ Orphaned ability cleaned up")
	
	print("✅ Delayed sacrifice at end of turn test passed!")
	return true

func test_delayed_effect_cleanup_on_turn_end() -> bool:
	"""Test delayed sacrifice cleanup when target dies before trigger - ability should still be cleaned up"""
	print("=== Testing Delayed Sacrifice Cleanup When Target Dies Early ===")
	
	# Step 1: Create a creature in play
	var target_creature = createCardFromName("Goblin", GameZone.e.BATTLEFIELD_PLAYER)
	print("  📦 Created creature: ", target_creature.cardName)
	
	# Step 2: Create a spell with delayed sacrifice trigger at end of turn
	var spell_card = CardData.new()
	spell_card.cardName = "Test Delayed Sacrifice Spell"
	spell_card.goldCost = 0
	spell_card.addType(CardData.CardType.SPELL)
	
	# Create spell effect with pre-parsed CreateDelayedEffect parameters
	var spell_effect = {
		"effect_type": EffectType.Type.CREATE_DELAYED_EFFECT,
		"effect_parameters": {
			"TriggerEvent": TriggeredAbility.GameEventType.END_OF_TURN,  # Trigger at end of turn
			"NestedEffectType": EffectType.Type.SACRIFICE,  # Sacrifice effect
			"NestedParameters": {
				"TargetCard": target_creature  # Will be set when spell is cast with target
			}
		}
	}
	spell_card.spell_effects.append(spell_effect)
	
	# Add spell to hand
	spell_card = game.createCardData(spell_card, GameZone.e.HAND_PLAYER, true)
	
	# Step 3: Verify orphaned_abilities is empty initially
	if not assert_test_equal(game.orphaned_abilities.size(), 0, "Should have no orphaned abilities initially"):
		return false
	
	# Step 4: Cast the spell with the creature as target
	var selections = SelectionManager.CardPlaySelections.new()
	selections.add_spell_target(target_creature)
	
	print("  🎯 Casting delayed sacrifice spell...")
	await game.tryPlayCard(spell_card, GameZone.e.BATTLEFIELD_PLAYER, selections)
	await test_runner.get_tree().process_frame
	
	# Step 5: Verify orphaned ability was created
	if not assert_test_equal(game.orphaned_abilities.size(), 1, "Should have 1 orphaned ability after casting"):
		return false
	print("  ✅ Orphaned ability created")
	
	# Step 6: Manually move creature to graveyard BEFORE end of turn
	print("  💀 Manually sacrificing creature before end of turn...")
	var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER
	await game.execute_move_card(target_creature, graveyard_zone)
	await test_runner.get_tree().process_frame
	
	# Step 7: Verify creature is in graveyard
	if not assertCardExists("Goblin", "graveyard"):
		return false
	if not assertCardCount(0, "play"):
		return false
	print("  ✅ Creature moved to graveyard early")
	
	# Step 8: Verify orphaned ability is still registered (hasn't been manually cleaned up)
	if not assert_test_equal(game.orphaned_abilities.size(), 1, "Orphaned ability should still exist"):
		return false
	
	# Step 9: End turn - orphaned ability should be cleaned up via cleanup_at_end_of_turn
	print("  🔄 Ending turn to trigger cleanup...")
	await game.onTurnStart()
	await test_runner.get_tree().process_frame
	await test_runner.get_tree().process_frame  # Extra frame for cleanup
	
	# Step 10: Verify orphaned ability was removed by end-of-turn cleanup
	if not assert_test_equal(game.orphaned_abilities.size(), 0, "Orphaned ability should be cleaned up at end of turn"):
		return false
	print("  ✅ Orphaned ability cleaned up at end of turn")
	
	print("✅ Delayed sacrifice cleanup test passed!")
	return true

func test_player_deck_building_data() -> bool:
	"""Test that PlayerDeckBuildingData builds a DeckList according to color/rarity limits and player overrides"""
	
	# --- Create test cards ---
	var red_common_a      = _make_raw_card("TestRedCommonA",      [CardData.CardColor.RED],                           CardData.Rarity.COMMON,   [CardData.CardType.CREATURE])
	var red_common_b      = _make_raw_card("TestRedCommonB",      [CardData.CardColor.RED],                           CardData.Rarity.COMMON,   [CardData.CardType.CREATURE])
	var red_uncommon      = _make_raw_card("TestRedUncommon",     [CardData.CardColor.RED],                           CardData.Rarity.UNCOMMON, [CardData.CardType.CREATURE])
	var red_rare          = _make_raw_card("TestRedRare",         [CardData.CardColor.RED],                           CardData.Rarity.RARE,     [CardData.CardType.CREATURE])
	var red_leg_mythic_1  = _make_raw_card("TestRedLegMythic1",  [CardData.CardColor.RED],                           CardData.Rarity.MYTHIC,   [CardData.CardType.CREATURE])
	var red_leg_mythic_2  = _make_raw_card("TestRedLegMythic2",  [CardData.CardColor.RED],                           CardData.Rarity.COMMON,   [CardData.CardType.LEGENDARY, CardData.CardType.CREATURE])
	var red_blue_common   = _make_raw_card("TestRedBlueCommon",  [CardData.CardColor.RED, CardData.CardColor.BLUE],  CardData.Rarity.COMMON,   [CardData.CardType.CREATURE])
	var blue_common       = _make_raw_card("TestBlueCommon",     [CardData.CardColor.BLUE],                          CardData.Rarity.COMMON,   [CardData.CardType.CREATURE])
	var black_blue_common = _make_raw_card("TestBlackBlueCommon",[CardData.CardColor.BLACK, CardData.CardColor.BLUE],CardData.Rarity.COMMON,   [CardData.CardType.CREATURE])
	
	# --- Register in CardLoader so getCardByName can resolve them by name ---
	var regular_cards: Array[CardData]  = [red_common_a, red_common_b, red_uncommon, red_rare,
											red_blue_common, blue_common, black_blue_common, red_leg_mythic_1]
	var legendary_cards: Array[CardData] = [red_leg_mythic_2]
	
	for card in regular_cards:
		CardLoaderAL.cardData.push_back(card)
	for card in legendary_cards:
		CardLoaderAL.extraDeckCardData.push_back(card)
	
	# --- Build PlayerDeckBuildingData ---
	var builder = PlayerDeckBuildingData.new()
	
	# Limits: Red at each rarity, Black Common, everything else stays 0
	builder.set_limit(CardData.CardColor.RED,   CardData.Rarity.COMMON,   4)
	builder.set_limit(CardData.CardColor.RED,   CardData.Rarity.UNCOMMON, 3)
	builder.set_limit(CardData.CardColor.RED,   CardData.Rarity.RARE,     2)
	builder.set_limit(CardData.CardColor.RED,   CardData.Rarity.MYTHIC,   1)
	builder.set_limit(CardData.CardColor.BLACK, CardData.Rarity.COMMON,   1)
	
	# Own all test cards
	for card in regular_cards + legendary_cards:
		builder.add_owned_card(card.cardName)
	
	# TestRedCommonB: player wants only 1 copy instead of the limit of 4
	builder.set_card_count_override("TestRedCommonB", 1)
	
	# --- Build the DeckList ---
	var deck_list = builder.build_deck_list()
	
	# --- Assertions: deck_cards (non-legendary) ---
	# Expected total: 4 + 1 + 3 + 2 + 1 + 4 + 0 + 1 = 16 (includes TestRedLegMythic1 as non-legendary mythic)
	assert_test_equal(deck_list.deck_cards.size(), 16,
		"deck_cards should have 16 total (4+1+3+2+1+4+0+1)")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestRedCommonA"), 4,
		"TestRedCommonA: Red Common limit=4 → 4 copies")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestRedCommonB"), 1,
		"TestRedCommonB: player override=1 → 1 copy")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestRedUncommon"), 3,
		"TestRedUncommon: Red Uncommon limit=3 → 3 copies")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestRedRare"), 2,
		"TestRedRare: Red Rare limit=2 → 2 copies")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestRedLegMythic1"), 1,
		"TestRedLegMythic1: Red Mythic limit=1 → 1 copy in deck (non-legendary)")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestRedBlueCommon"), 4,
		"TestRedBlueCommon: max(Red Common=4, Blue Common=0) → 4 copies")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestBlueCommon"), 0,
		"TestBlueCommon: Blue Common limit=0 → 0 copies (absent from deck)")
	
	assert_test_equal(_count_cards_by_name(deck_list.deck_cards, "TestBlackBlueCommon"), 1,
		"TestBlackBlueCommon: max(Black Common=1, Blue Common=0) → 1 copy")
	
	# --- Assertions: extra_deck_cards (legendary) ---
	# Expected total: 4 (TestRedLegMythic2 is Red/Common/Legendary → limit=4)
	assert_test_equal(deck_list.extra_deck_cards.size(), 4,
		"extra_deck_cards should have 4 total")
	
	assert_test_equal(_count_cards_by_name(deck_list.extra_deck_cards, "TestRedLegMythic2"), 4,
		"TestRedLegMythic2: Red Common limit=4 → 4 copies in extra deck")
	
	# --- Cleanup: reload CardLoader to remove test cards ---
	CardLoaderAL.load_all_cards()
	
	return not current_test_failed

func _count_cards_by_name(cards: Array[CardData], name: String) -> int:
	var count = 0
	for card in cards:
		if card.cardName == name:
			count += 1
	return count

func _make_raw_card(card_name: String, colors: Array, rarity: CardData.Rarity, types: Array) -> CardData:
	"""Create a raw CardData with color/rarity set, not registered in any game zone.
	Use this when you need a template for CardLoader injection (e.g. deck builder tests).
	For cards that participate in game logic, use createTestCard or createCardFromName instead."""
	var c = CardData.new()
	c.cardName = card_name
	c.rarity = rarity
	for col in colors:
		c.colors.append(col)
	for t in types:
		c._types.append(t)
	return c
