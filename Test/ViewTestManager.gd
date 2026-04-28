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
	await game.game_view.arrange_extra_deck_hand(castable_cards)

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

func test_container_visualizer_graveyard_selection() -> bool:
	"""Test that selecting cards from graveyard opens the container visualizer UI"""
	
	# Step 1: Create a creature in graveyard
	var graveyard_creature = CardData.new()
	graveyard_creature.cardName = "GraveyardCreature"
	graveyard_creature.goldCost = 0
	graveyard_creature._power = 2
	graveyard_creature.addType(CardData.CardType.CREATURE)
	graveyard_creature.playerControlled = true
	graveyard_creature.playerOwned = true
	# Use createCardData to properly create both data and view
	graveyard_creature = game.createCardData(graveyard_creature, GameZone.e.GRAVEYARD_PLAYER, true)
	
	if not assert_test_equal(game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER).size(), 1, "Graveyard should have 1 creature"):
		return false
	
	# Step 2: Create a test spell that asks to select a creature from graveyard
	var test_spell = CardData.new()
	test_spell.cardName = "TestGraveyardSpell"
	test_spell.goldCost = 0
	test_spell.addType(CardData.CardType.SPELL)
	test_spell.playerControlled = true
	test_spell.playerOwned = true
	
	# Add spell effect: MoveCard from graveyard to battlefield
	var spell_effect = {
		"effect_type": EffectType.Type.MOVE_CARD,
		"effect_parameters": {
			"Origin": "Graveyard.Player",
			"Destination": "Battlefield.Player",
			"ValidCard": "Creature",
			"NumCard": 1,
			"Choice": "Player"
		}
	}
	test_spell.spell_effects.append(spell_effect)
	
	# Use createCardData to properly create both data and view
	test_spell = game.createCardData(test_spell, GameZone.e.HAND_PLAYER, true)
	setPlayerGold(99)
	
	# Step 3: Start casting the spell (this should trigger selection)
	# We need to intercept the selection process to test UI state
	# Use a dictionary to avoid GDScript closure variable capture issues
	var test_state = {
		"visualizer_shown": false,
		"cancel_button_visible": false,
		"validate_button_disabled_initially": false,
		"validate_button_enabled_after_selection": false
	}
	
	# Connect to selection_started signal to check UI state
	game.selection_manager.selection_started.connect(
		func():
			# Debug: Check what's actually visible
			print("🔍 [TEST DEBUG] selection_started fired")
			print("  Visualizer visible: ", game.game_view.container_visualizer.visible)
			print("  Cancel button visible: ", game.game_view.secondary_action_button.visible)
			print("  Main button disabled: ", game.game_view.main_action_button.disabled)
			
			# Check that visualizer is shown (synchronous check)
			test_state["visualizer_shown"] = game.game_view.container_visualizer.visible
			
			# Check that cancel button is visible (synchronous check)
			test_state["cancel_button_visible"] = game.game_view.secondary_action_button.visible
			
			# Check that validate button is disabled initially (synchronous check)
			test_state["validate_button_disabled_initially"] = game.game_view.main_action_button.disabled
			
			print("🔍 [TEST DEBUG] Variables set:")
			print("  visualizer_shown: ", test_state["visualizer_shown"])
			print("  cancel_button_visible: ", test_state["cancel_button_visible"])
			print("  validate_button_disabled_initially: ", test_state["validate_button_disabled_initially"])
			
			# Defer the async card click simulation to avoid blocking the signal handler
			var async_handler = func():
				# Wait a frame for visualizer cards to be fully initialized
				await test_runner.get_tree().process_frame
				
				# Simulate clicking the card in the visualizer
				var h_box = game.game_view.container_visualizer.h_box_container
				print("🔍 [TEST DEBUG] h_box child count: ", h_box.get_child_count())
				
				if h_box.get_child_count() > 0:
					var card2d = h_box.get_child(0)
					print("🔍 [TEST DEBUG] card2d type: ", card2d.get_class() if card2d else "null")
					
					if card2d is Card2D:
						# Use the CardData from the visualizer, not our test variable
						# (ensures we select the actual instance in the game)
						var card_from_visualizer = card2d.cardData
						print("🔍 [TEST DEBUG] card_from_visualizer: ", card_from_visualizer.cardName if card_from_visualizer else "null")
						
						if not card_from_visualizer:
							print("❌ [TEST DEBUG] Card2D has no cardData!")
							return
						
						# Simulate card click
						game.selection_manager._on_visualizer_card_clicked(card_from_visualizer)
						
						# Wait a frame for UI update
						await test_runner.get_tree().process_frame
						
						# Check that validate button is now enabled
						test_state["validate_button_enabled_after_selection"] = not game.game_view.main_action_button.disabled
						print("🔍 [TEST DEBUG] Button enabled after selection: ", test_state["validate_button_enabled_after_selection"])
						
						# Click the validate button
						game.selection_manager.validate_selection()
						print("🔍 [TEST DEBUG] Validate clicked")
			
			# Run the async handler deferred
			async_handler.call()
	,
	CONNECT_ONE_SHOT
)	
	# Cast the spell - this should trigger the selection
	await game.tryPlayCard(test_spell, GameZone.e.BATTLEFIELD_PLAYER)
	
	# Wait for async handler to complete (give it a few frames)
	for i in range(5):
		await test_runner.get_tree().process_frame
	
	# Step 4: Assert UI was displayed correctly
	if not assert_test_true(test_state["visualizer_shown"], "Container visualizer should be shown during selection"):
		return false
	
	if not assert_test_true(test_state["cancel_button_visible"], "Cancel button should be visible during selection"):
		return false
	
	if not assert_test_true(test_state["validate_button_disabled_initially"], "Validate button should be disabled initially"):
		return false
	
	if not assert_test_true(test_state["validate_button_enabled_after_selection"], "Validate button should be enabled after selecting a card"):
		return false
	
	# Step 5: Assert the selected card was correctly used (moved from graveyard to battlefield)
	var graveyard_cards = game.game_data.get_cards_in_zone(GameZone.e.GRAVEYARD_PLAYER)
	var battlefield_size = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER).size()
	
	var creature_still_in_graveyard = false
	for card in graveyard_cards:
		if card.cardName == "GraveyardCreature":
			creature_still_in_graveyard = true
			break
	if not assert_test_false(creature_still_in_graveyard, "GraveyardCreature should be moved out of graveyard"):
		return false
	
	if not assert_test_equal(battlefield_size, 1, "Battlefield should have 1 creature after move"):
		return false
	
	# Verify the creature on battlefield is the one from graveyard
	var battlefield_cards = game.game_data.get_cards_in_zone(GameZone.e.BATTLEFIELD_PLAYER)
	if not assert_test_equal(battlefield_cards[0].cardName, "GraveyardCreature", "Moved creature should be the one from graveyard"):
		return false
	
	# Step 6: Assert visualizer is closed after selection
	if not assert_test_false(game.game_view.container_visualizer.visible, "Visualizer should be hidden after selection completes"):
		return false
	
	print("✅ Container visualizer graveyard selection test passed!")
	return true
