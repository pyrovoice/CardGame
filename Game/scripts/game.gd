extends Node3D
class_name Game

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: Node3D = $Camera3D/PlayerHand
@onready var deck: Deck = $"Deck"
@onready var combatZones: Array = [$combatZone, $combatZone2, $combatZone3]
@onready var game_ui: GameUI = $UI
@onready var player_base: PlayerBase = $playerBase
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var card_popup: SubViewport = $cardPopup
@onready var card_in_popup: Card = $cardPopup/Card
var playerControlLock:PlayerControlLock = PlayerControlLock.new()
@onready var graveyard: Graveyard = $graveyard
@onready var extra_deck: CardContainer = $extraDeck
@onready var draw: Button = $UI/draw

# Game data and state management
var game_data: GameData

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

# Container for castable extra deck cards (displayed to the right of hand)
@onready var extra_deck_display: Node3D = $Camera3D/extra_deck_display

func _ready() -> void:
	# Initialize game data
	game_data = GameData.new()
	
	# Setup UI to follow SignalFloat signals
	game_ui.setup_game_data(game_data)
	
	# Set up payment manager context
	CardPaymentManagerAL.set_game_context(self)
	
	player_control.tryMoveCard.connect(tryMoveCard)
	draw.pressed.connect(onTurnStart)
	CardLoader.load_all_cards()
	
	# Test additional cost parsing for Goblin Boss
	test_additional_costs()
	
	populate_deck()
	createOpposingToken()
	drawCard()
	drawCard()
	drawCard()

func populate_deck():
	deck.clear_cards()
	extra_deck.clear_cards()
	
	for card_data in CardLoader.cardData:
		# Boss cards go to extra deck, others go to regular deck
		if card_data.hasType(CardData.CardType.BOSS):
			extra_deck.add_card(card_data)
		else:
			deck.add_card(card_data)

func onTurnStart():
	# Start a new turn (increases danger level via SignalFloat)
	game_data.start_new_turn()
	
	await resolveCombats()
	drawCard()
	createOpposingToken()

func tryMoveCard(card: Card, target_location: Node3D) -> void:
	"""Attempt to move a card to the specified location - handles different movement types based on source zone"""
	if not target_location or not card:
		return
	
	var source_zone = getCardZone(card)
	var _target_zone = _getTargetZone(target_location)
	
	match source_zone:
		GameZone.e.HAND:
			# Playing from hand - use the full play logic
			tryPlayCard(card, target_location)
			arrange_cards_fan()
		
		GameZone.e.PLAYER_BASE:
			# Moving from PlayerBase to combat - this is an attack
			if target_location is CombatantFightingSpot:
				executeCardAttacks(card, target_location as CombatantFightingSpot)
			else:
				print("❌ Cannot move card from PlayerBase to non-combat location")
		
		GameZone.e.COMBAT_ZONE:
			# Moving from combat back to PlayerBase - retreat/return
			if target_location is PlayerBase:
				moveCardToPlayerBase(card)
			else:
				print("❌ Cannot move card from CombatZone to non-PlayerBase location")
		
		_:
			print("❌ Cannot move card from zone: ", source_zone)
	
func tryPlayCard(card: Card, target_location: Node3D) -> void:
	"""Attempt to play a card to the specified location"""
	if not target_location or not card:
		return
	
	var source_zone = getCardZone(card)
	
	# Validate the play attempt
	if not _canPlayCard(card, source_zone, target_location):
		return
	
	# Pay costs if playing from hand or extra deck
	if source_zone == GameZone.e.HAND or source_zone == GameZone.e.EXTRA_DECK:
		if not CardPaymentManagerAL.tryPayCard(card):
			return
	
	# Determine target zone and execute the play
	var target_zone = _getTargetZone(target_location)
	_executeCardPlay(card, source_zone, target_zone, target_location)
	
	# If target was combat location, also execute the attack
	if target_location is CombatantFightingSpot:
		executeCardAttacks(card, target_location as CombatantFightingSpot)

func _canPlayCard(card: Card, source_zone: GameZone.e, target_location: Node3D) -> bool:
	"""Check if the card can be played to the target location"""
	# Can play cards from hand or extra deck
	var can_play_from_zone = (source_zone == GameZone.e.HAND) or (source_zone == GameZone.e.EXTRA_DECK)
	if not can_play_from_zone:
		return false
	
	# Basic playability check
	print("Attempting to play card: ", card.cardData.cardName, " (Cost: ", card.cardData.goldCost, ")")
	debug_player_resources()
	
	if not isCardPlayable(card):
		print("❌ Card not playable!")
		return false
	
	print("✅ Card is playable, proceeding...")
	
	# Check target location availability
	if target_location is CombatantFightingSpot:
		var combat_spot = target_location as CombatantFightingSpot
		if combat_spot.getCard() != null:
			# TODO: Add fallback to next available spot or PlayerBase
			return false
	
	return true

func _getTargetZone(target_location: Node3D) -> GameZone.e:
	"""Determine the game zone for the target location"""
	if target_location is CombatantFightingSpot:
		return GameZone.e.COMBAT_ZONE
	elif target_location is PlayerBase:
		return GameZone.e.PLAYER_BASE
	else:
		# Default to player base for unknown locations
		return GameZone.e.PLAYER_BASE

func _executeCardPlay(card: Card, source_zone: GameZone.e, _target_zone: GameZone.e, _target_location: Node3D):
	"""Execute the card play to battlefield (PlayerBase) and trigger appropriate game actions"""
	# Trigger CARD_PLAYED action first (before the card moves)
	var played_action = GameAction.new(TriggerType.Type.CARD_PLAYED, card, source_zone, GameZone.e.PLAYER_BASE)
	AbilityManagerAL.triggerGameAction(self, played_action)
	
	# Move the card to player base
	var play_successful = await moveCardToPlayerBase(card)
	
	if not play_successful:
		print("❌ Failed to play card to player base")
		return
	
	# Trigger CARD_ENTERS action after the card has moved to battlefield
	var enters_action = GameAction.new(TriggerType.Type.CARD_ENTERS, card, source_zone, GameZone.e.PLAYER_BASE)
	AbilityManagerAL.triggerGameAction(self, enters_action)
	
	# Resolve state-based actions after card play
	resolveStateBasedAction()

func executeCardAttacks(card: Card, combat_spot: CombatantFightingSpot):
	"""Execute card attack - move card from PlayerBase to CombatZone and trigger attack"""
	var source_zone = getCardZone(card)  # Should be PLAYER_BASE
	
	# Move the card to combat zone
	var attack_successful = await moveCardToCombatZone(card, combat_spot)
	
	if not attack_successful:
		print("❌ Failed to move card to combat zone")
		return
	
	# Trigger CARD_ATTACKS action after the card has moved to combat zone
	var attacks_action = GameAction.new(TriggerType.Type.CARD_ATTACKS, card, source_zone, GameZone.e.COMBAT_ZONE)
	AbilityManagerAL.triggerGameAction(self, attacks_action)
	
	# Resolve state-based actions after attack
	resolveStateBasedAction()
	
func isCardPlayable(card: Card) -> bool:
	"""Check if a card can be played (in hand/extra deck and affordable)"""
	var card_zone = getCardZone(card)
	
	# Card must be in hand or extra deck to be playable
	if card_zone != GameZone.e.HAND and card_zone != GameZone.e.EXTRA_DECK:
		return false
	
	return CardPaymentManagerAL.canPayCard(card)  # Check if player can afford it

func moveCardToCombatZone(card: Card, zone: CombatantFightingSpot) -> bool:
	zone.setCard(card)
	await AnimationsManagerAL.animate_card_to_position(card, zone.global_position + Vector3(0, 0.1, 0))
	return true

func moveCardToPlayerBase(card: Card) -> bool:
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:  # No empty location available
		return false
	
	# Convert local position to global position
	var global_target = player_base.global_position + target_position
	card.reparent(player_base)
	await AnimationsManagerAL.animate_card_to_position(card, global_target + Vector3(0, 0.1, 0))
	resolveStateBasedAction()
	return true

func drawCard():
	var card = deck.draw_card_from_top()
	if card == null:
		return
	card.reparent(player_hand, false)
	
	# Trigger card drawn action
	var action = GameAction.new(TriggerType.Type.CARD_DRAWN, card, GameZone.e.DECK, GameZone.e.HAND)
	AbilityManagerAL.triggerGameAction(self, action)
	
	arrange_cards_fan()
	
	# Resolve state-based actions after drawing card
	resolveStateBasedAction()

func arrange_cards_fan():
	var cards = player_hand.get_children()
	var count = cards.size()
	if count == 0:
		return
	
	var spacing = 0.75       # Horizontal space between cards
	
	# Clamp count to max 10 if needed
	count = min(count, 10)
	
	# Calculate starting offset to center the cards
	var total_width = spacing * (count - 1)
	var start_x = -total_width / 2
	
	for i in range(count):
		var card: Card = cards[i]
		if not card is Card:
			continue
		
		# Position cards spread horizontally
		card.position.x = start_x + spacing * i

func resolveCombats():
	var lock = playerControlLock.addLock()
	for cv in combatZones:
		await resolveCombatInZone(cv)
	playerControlLock.removeLock(lock)
	
func resolveCombatInZone(combatZone: CombatZone):
	var _damageCounter = 0
	
	# Animate combat for each slot
	for i in range(1, 4):
		var allyCard = combatZone.getCardSlot(i, true).getCard()
		var oppCard = combatZone.getCardSlot(i, false).getCard()
		
		if allyCard && oppCard:
			# Animate opponent card striking ally card
			await AnimationsManagerAL.animate_combat_strike(oppCard, allyCard)
			
			# Apply damage after animation
			allyCard.receiveDamage(oppCard.getPower())
			oppCard.receiveDamage(allyCard.getPower())

		elif allyCard && !oppCard:
			_damageCounter += allyCard.getPower()
		elif !allyCard && oppCard:
			_damageCounter -= oppCard.getPower()
	
	resolveStateBasedAction()
	
	#HERE: Add animation for +1 point or -1 life
	var player_strength = combatZone.getTotalStrengthForSide(true)
	var opponent_strength = combatZone.getTotalStrengthForSide(false)
	
	if player_strength > opponent_strength:
		AnimationsManagerAL.show_floating_text(self, combatZone.global_position, "+1 Point", Color.GREEN)
		var current_points = game_ui.player_point.text.to_int() if game_ui.player_point else 0
		game_data.add_player_points(1)
	elif player_strength < opponent_strength:
		AnimationsManagerAL.show_floating_text(self, combatZone.global_position, "-1 Life", Color.RED)
		damage_player(1)
	else:
		AnimationsManagerAL.show_floating_text(self, combatZone.global_position, "Draw", Color.YELLOW)
	resolveStateBasedAction()

func resolveStateBasedAction():
	var cards_in_play = getAllCardsInPlay()
	
	for c:Card in cards_in_play:
		var damage = c.getDamage()
		var power = c.getPower()
		
		if damage >= power:
			putInOwnerGraveyard(c)
	if game_data.player_life.getValue() <= 0:
		print("Player lose")
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	if game_data.player_points.getValue() >= 6:
		print("Player win")
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	
	# Check and highlight castable cards
	highlightCastableCards()

func createOpposingToken():
	if not game_data:
		return
		
	var danger_level = game_data.danger_level.getValue()
	var increment_counter = 0
	
	while increment_counter < danger_level:
		# Roll a random value from 1 to dangerLevel/2 (rounded up)
		var max_roll = max(1, ceil(danger_level / 2.0))
		var rolled_value = randi_range(1, max_roll)
		
		# Add the rolled value to the counter
		increment_counter += rolled_value
		
		# Create a token with the rolled value as power
		var card = CARD.instantiate()
		add_child(card)
		card.setData(CardData.new("Enemy", 0, [CardData.CardType.CREATURE], rolled_value, ""))
		
		# Create a pool of available combat zones (indices)
		var available_zones = []
		for i in range(combatZones.size()):
			available_zones.append(i)
		
		var token_placed = false
		
		# Try to place the token in available zones
		while available_zones.size() > 0 and not token_placed:
			# Choose a random zone from available zones
			var random_index = randi_range(0, available_zones.size() - 1)
			var zone_index = available_zones[random_index]
			var chosen_combat_zone = combatZones[zone_index]
			
			# Get the first empty location on the enemy side (false)
			var location: CombatantFightingSpot = chosen_combat_zone.getFirstEmptyLocation(false)
			if location:
				location.setCard(card, false)
				token_placed = true
			else:
				# Remove this zone from available zones and try again
				available_zones.remove_at(random_index)
		
		# If no zones are available, destroy the card and stop
		if not token_placed:
			card.queue_free()
			print("No empty locations found in any combat zone - token destroyed, stopping token creation")
			break

func getAllCardsInPlay() -> Array[Card]:
	var cards:Array[Card] = player_base.getCards()
	for cz:CombatZone in combatZones:
		cz.allySpots.filter(func(c:CombatantFightingSpot): return c.getCard() != null).map(func(c:CombatantFightingSpot): cards.push_back(c.getCard()))
		cz.ennemySpots.filter(func(c:CombatantFightingSpot): return c.getCard() != null).map(func(c:CombatantFightingSpot): cards.push_back(c.getCard()))
	return cards 

func putInOwnerGraveyard(card: Card):
	await card.animatePlayedTo(graveyard.global_position)
	graveyard.add_card(card.cardData)
	card.queue_free()

static var objectCount = 0
static func getObjectCountAndIncrement():
	objectCount +=1
	return objectCount-1
	
func createCardFromData(cardData: CardData):
	if cardData == null:
		push_warning("Tried to draw from empty deck.")
		return null
	
	if !CARD.can_instantiate():
		push_error("Can't instantiate.")
		return
	var card_instance: Card = CARD.instantiate() as Card
	if card_instance == null:
		push_error("Card instance is null! Check if Card.gd is attached to Card.tscn root.")
		return
	add_child(card_instance)
	card_instance.setData(cardData)
	card_instance.name = cardData.cardName + "_" + str(getObjectCountAndIncrement())
	return card_instance

func getCardZone(card: Card) -> GameZone.e:
	"""Determine what zone a card is currently in based on its parent"""
	var parent = card.get_parent()
	if not parent:
		return GameZone.e.DECK # Default fallback
	
	var parent_name = parent.name
	
	# Check parent name/type to determine zone
	if parent_name == "PlayerHand":
		return GameZone.e.HAND
	elif parent_name == "playerBase" or parent.get_script() != null and parent.get_script().get_global_name() == "PlayerBase":
		return GameZone.e.PLAYER_BASE
	elif parent_name.begins_with("combatZone") or parent.get_script() != null and parent.get_script().get_global_name() == "CombatantFightingSpot":
		return GameZone.e.COMBAT_ZONE
	elif parent_name == "graveyard" or parent.get_script() != null and parent.get_script().get_global_name() == "Graveyard":
		return GameZone.e.GRAVEYARD
	elif parent_name == "Deck" or parent.get_script() != null and parent.get_script().get_global_name() == "Deck":
		return GameZone.e.DECK
	elif parent_name == "extraDeck" or parent.get_script() != null and parent.get_script().get_global_name() == "CardContainer":
		return GameZone.e.EXTRA_DECK
		
		# Default fallback
	return GameZone.e.DECK

# Game Data Access Functions
func get_game_data() -> GameData:
	"""Get the current game data"""
	return game_data

func damage_player(amount: float):
	"""Apply damage to the player"""
	if game_data:
		game_data.damage_player(amount)

func heal_player(amount: float):
	"""Heal the player"""
	if game_data:
		game_data.heal_player(amount)

func restore_shield(amount: float):
	"""Restore player shield"""
	if game_data:
		game_data.restore_shield(amount)

func is_game_over() -> bool:
	"""Check if the game is over (player defeated)"""
	return game_data and game_data.is_player_defeated()

func debug_player_resources():
	"""Debug function to print current player resources"""
	if game_data:
		print("=== PLAYER RESOURCES ===")
		print("Life: ", game_data.player_life.value)
		print("Shield: ", game_data.player_shield.value)
		print("Gold: ", game_data.player_gold.value)
		print("Points: ", game_data.player_points.value)
		print("Turn: ", game_data.current_turn.value)
		print("Danger Level: ", game_data.danger_level.value)
		print("========================")

func highlightCastableCards():
	"""Check cards in hand and extra deck for castability and update their display"""
	# Check cards in hand for highlighting
	_highlightHandCards()
	
	# Check extra deck cards and display castable ones
	_displayCastableExtraDeckCards()

func _highlightHandCards():
	"""Toggle highlight on cards in hand based on castability"""
	var hand_cards = player_hand.get_children()
	for card: Card in hand_cards:
		if card is Card:
			var is_castable = CardPaymentManagerAL.isCardCastable(card)
			card.highlight(is_castable)

func _displayCastableExtraDeckCards():
	"""Display castable extra deck cards to the right of the hand"""
	# Clear existing extra deck display
	_clearExtraDeckDisplay()
	
	# Check each card in extra deck for castability
	var castable_cards: Array[CardData] = []
	print("=== Extra Deck Castability Check ===")
	print("Extra deck has ", extra_deck.cards.size(), " cards")
	
	for card_data: CardData in extra_deck.cards:
		print("Checking card: ", card_data.cardName)
		print("  Gold cost: ", card_data.goldCost)
		print("  Player gold: ", game_data.player_gold.value)
		print("  Has gold: ", game_data.has_gold(card_data.goldCost))
		print("  Has additional costs: ", card_data.hasAdditionalCosts())
		if card_data.hasAdditionalCosts():
			print("  Additional costs: ", card_data.getAdditionalCosts())
		
		var is_castable = CardPaymentManagerAL.isCardDataCastable(card_data)
		print("  Is castable: ", is_castable)
		
		if is_castable:
			castable_cards.append(card_data)
	
	print("Castable cards: ", castable_cards.size())
	print("=====================================")
	
	# Display castable cards
	_arrangeExtraDeckCards(castable_cards)

func _createExtraDeckDisplay():
	"""Create the container for extra deck card display"""
	extra_deck_display = Node3D.new()
	extra_deck_display.name = "ExtraDeckDisplay"
	player_hand.get_parent().add_child(extra_deck_display)
	
	# Position it to the right of the hand area
	extra_deck_display.position = Vector3(8, 0, 0)  # Adjust position as needed

func _clearExtraDeckDisplay():
	"""Clear all cards from the extra deck display"""
	if extra_deck_display:
		for child in extra_deck_display.get_children():
			child.queue_free()

func _arrangeExtraDeckCards(castable_cards: Array[CardData]):
	"""Arrange castable extra deck cards in the display area"""
	if not extra_deck_display or castable_cards.is_empty():
		return
	
	var spacing = 0.8  # Horizontal spacing between cards
	var start_x = 0
	
	for i in range(castable_cards.size()):
		var card_data = castable_cards[i]
		var card_instance = createCardFromData(card_data)
		
		if card_instance:
			# Add to extra deck display
			card_instance.reparent(extra_deck_display)
			
			# Position the card
			card_instance.position.x = start_x + spacing * i
			card_instance.position.y = 0
			card_instance.position.z = 0
			
			# Make sure it's visible and properly sized
			card_instance.makeSmall()
			
			# Add some visual indication that it's from extra deck (e.g., glow effect)
			card_instance.set_glow_effect(true, Color.GOLD, 0.5)

func test_additional_costs():
	"""Test function to verify additional cost parsing and checking"""
	print("=== Testing Additional Cost System ===")
	
	# Find Goblin Boss card
	var goblin_boss_data = null
	for card_data in CardLoader.cardData:
		if card_data.cardName == "Goblin Boss":
			goblin_boss_data = card_data
			break
	
	if not goblin_boss_data:
		print("❌ Goblin Boss not found in card data")
		return
	
	print("✅ Found Goblin Boss")
	print("   Gold Cost: ", goblin_boss_data.goldCost)
	print("   Has Additional Costs: ", goblin_boss_data.hasAdditionalCosts())
	
	if goblin_boss_data.hasAdditionalCosts():
		print("   Additional Costs: ", goblin_boss_data.additionalCosts)
		print("   Cost Description: ", goblin_boss_data.getAdditionalCostDescription())
	
	# Test castability checking
	print("   Player Gold: ", game_data.player_gold.value)
	print("   Can Pay Gold Cost: ", game_data.has_gold(goblin_boss_data.goldCost))
	
	if goblin_boss_data.hasAdditionalCosts():
		var can_pay_additional = CardPaymentManagerAL.canPayAdditionalCosts(goblin_boss_data.getAdditionalCosts())
		print("   Can Pay Additional Costs: ", can_pay_additional)
		print("   Player Controlled Cards: ", CardPaymentManagerAL.getPlayerControlledCards().size())
		
		# Show which cards player controls
		var controlled = CardPaymentManagerAL.getPlayerControlledCards()
		for card in controlled:
			print("     - ", card.cardData.cardName, " (", card.cardData.subtypes, ")")
	
	print("===")
