extends RefCounted
class_name GameTestEnvironment

# Lightweight game state for testing - no 3D dependencies
# Simulates the core game logic without scenes or UI

var player_hand: Array = []
var player_base: Array = []
var combat_zones: Array[Array] = [[], [], []]  # 3 combat zones with ally/enemy sides
var deck: Array[CardData] = []
var graveyard: Array[CardData] = []
var player_points: int = 0

# Game state tracking
var game_actions_history: Array[GameAction] = []
var ability_triggers_history: Array[Dictionary] = []

func _init():
	# Initialize with test data
	_setup_test_environment()

func _setup_test_environment():
	"""Setup a clean test environment"""
	player_hand.clear()
	player_base.clear()
	for zone in combat_zones:
		zone.clear()
	deck.clear()
	graveyard.clear()
	player_points = 0
	game_actions_history.clear()
	ability_triggers_history.clear()
	
	# Load card data for testing
	CardLoader.load_all_cards()
	deck = CardLoader.cardData.duplicate()

func create_test_card(card_name: String):
	"""Create a test card instance without 3D scene dependencies"""
	var card_data = _find_card_data_by_name(card_name)
	if not card_data:
		push_error("Test card not found: " + card_name)
		return null
	
	# Create a minimal Card instance for testing
	var test_card = TestCard.new()
	test_card.cardData = card_data
	test_card.objectID = card_name + "_test_" + str(Time.get_unix_time_from_system())
	test_card.current_zone = "hand"  # Default to hand when created
	return test_card

func _find_card_data_by_name(name: String) -> CardData:
	"""Find card data by name"""
	for card_data in deck:
		if card_data.cardName == name:
			return card_data
	return null

# === GAME ACTIONS ===

func play_card_from_hand(card_name: String, target_zone: String = "player_base") -> bool:
	"""Simulate playing a card from hand"""
	var card = _find_card_in_hand(card_name)
	if not card:
		return false
	
	# Remove from hand
	player_hand.erase(card)
	
	# Add to target zone
	player_base.append(card)
	
	# Update card's zone tracking
	if card.has_method("set_current_zone"):
		card.set_current_zone("player_base")
	elif "current_zone" in card:
		card.current_zone = "player_base"
	
	# Create game actions
	var play_action = GameAction.new(TriggerType.Type.CARD_PLAYED, card, GameZone.e.HAND, GameZone.e.PLAYER_BASE)
	var enters_action = GameAction.new(TriggerType.Type.CARD_ENTERS, card, GameZone.e.HAND, GameZone.e.PLAYER_BASE)
	
	# Trigger abilities
	_trigger_game_action(play_action)
	_trigger_game_action(enters_action)
	
	# If targeting combat, also attack
	if target_zone.begins_with("combat"):
		attack_with_card(card_name, target_zone)
	
	return true

func attack_with_card(card_name: String, combat_zone: String = "combat_0") -> bool:
	"""Move a card from player base to combat zone"""
	var card = _find_card_in_player_base(card_name)
	if not card:
		return false
	
	# Remove from player base
	player_base.erase(card)
	
	# Add to combat zone (assume ally side)
	var zone_index = int(combat_zone.split("_")[1]) if "_" in combat_zone else 0
	if zone_index < combat_zones.size():
		combat_zones[zone_index].append(card)
	
	# Create and trigger attack action
	var attack_action = GameAction.new(TriggerType.Type.CARD_ATTACKS, card, GameZone.e.PLAYER_BASE, GameZone.e.COMBAT_ZONE)
	_trigger_game_action(attack_action)
	
	return true

func draw_card():
	"""Draw a card from deck to hand"""
	if deck.is_empty():
		return null
	
	var card_data = deck.pop_front()
	var card = TestCard.new()
	card.cardData = card_data
	card.objectID = card_data.cardName + "_drawn_" + str(Time.get_unix_time_from_system())
	
	player_hand.append(card)
	
	# Trigger draw action
	var draw_action = GameAction.new(TriggerType.Type.CARD_DRAWN, card, GameZone.e.DECK, GameZone.e.HAND)
	_trigger_game_action(draw_action)
	
	return card

func _trigger_game_action(action: GameAction):
	"""Simulate triggering a game action through AbilityManager"""
	game_actions_history.append(action)
	
	# Get all cards that could trigger
	var all_cards = get_all_cards_in_play()
	
	# Use AbilityManager to get triggered abilities
	var triggered_abilities = AbilityManagerAL.getTriggeredAbilities(all_cards, action)
	
	# Execute each triggered ability
	for ability_pair in triggered_abilities:
		var triggering_card = ability_pair.card
		var ability = ability_pair.ability
		ability_triggers_history.append({
			"card": triggering_card.cardData.cardName,
			"ability": ability,
			"trigger": action.get_trigger_type_string()
		})
		
		# Execute the ability (simplified for testing)
		_execute_test_ability(triggering_card, ability)

func _execute_test_ability(card, ability: Dictionary):
	"""Execute an ability in the test environment"""
	var effect_name = ability.get("effect_name", "")
	var effect_parameters = ability.get("effect_parameters", {})
	
	match effect_name:
		"TrigToken":
			_test_create_token(effect_parameters, card)
		"TrigDraw", "Draw":
			_test_draw_card(effect_parameters)
		_:
			print("Unknown test effect: ", effect_name)

func _test_create_token(parameters: Dictionary, _source_card):
	"""Test token creation"""
	var token_script = parameters.get("TokenScript", "")
	if token_script.is_empty():
		return
	
	var token_data = CardLoader.load_token_by_name(token_script)
	if token_data:
		var token_card = TestCard.new()
		token_card.cardData = token_data
		token_card.objectID = token_data.cardName + "_token_" + str(Time.get_unix_time_from_system())
		player_base.append(token_card)

func _test_draw_card(parameters: Dictionary):
	"""Test card draw"""
	var cards_to_draw = int(parameters.get("NumCards", "1"))
	for i in range(cards_to_draw):
		draw_card()

# === HELPER FUNCTIONS ===

func get_all_cards_in_play() -> Array:
	"""Get all cards currently in play"""
	var cards: Array = []
	cards.append_array(player_base)
	for zone in combat_zones:
		cards.append_array(zone)
	return cards

func _find_card_in_hand(card_name: String):
	for card in player_hand:
		if card.cardData.cardName == card_name:
			return card
	return null

func _find_card_in_player_base(card_name: String):
	for card in player_base:
		if card.cardData.cardName == card_name:
			return card
	return null

# === ASSERTION HELPERS ===

func assert_hand_size(expected: int) -> bool:
	return player_hand.size() == expected

func assert_player_base_size(expected: int) -> bool:
	return player_base.size() == expected

func assert_card_in_hand(card_name: String) -> bool:
	return _find_card_in_hand(card_name) != null

func assert_card_in_player_base(card_name: String) -> bool:
	return _find_card_in_player_base(card_name) != null

func assert_ability_triggered(card_name: String, trigger_type: String) -> bool:
	for trigger in ability_triggers_history:
		if trigger.card == card_name and trigger.trigger == trigger_type:
			return true
	return false

func assert_token_created(token_name: String) -> bool:
	for card in player_base:
		if card.cardData.cardName == token_name:
			return true
	return false

func get_cards_by_name(card_name: String) -> Array:
	"""Get all cards with a specific name"""
	var found_cards: Array = []
	var all_cards = get_all_cards_in_play()
	all_cards.append_array(player_hand)
	
	for card in all_cards:
		if card.cardData.cardName == card_name:
			found_cards.append(card)
	
	return found_cards

func print_game_state():
	"""Debug helper to print current game state"""
	print("=== GAME STATE ===")
	print("Hand: ", player_hand.map(func(c): return c.cardData.cardName))
	print("Player Base: ", player_base.map(func(c): return c.cardData.cardName))
	print("Combat Zones: ", combat_zones.map(func(zone): return zone.map(func(c): return c.cardData.cardName)))
	print("Deck Size: ", deck.size())
	print("Graveyard: ", graveyard.map(func(c): return c.cardName))
	print("Player Points: ", player_points)
	print("Actions History: ", game_actions_history.size())
	print("Triggers History: ", ability_triggers_history.size())
