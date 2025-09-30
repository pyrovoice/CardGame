extends Node3D
class_name Game

const OpponentAIScript = preload("res://Game/scripts/OpponentAI.gd")

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: Node3D = $Camera3D/PlayerHand
@onready var opponent_hand: Node3D = $opponentHand
@onready var deck: Deck = $"Deck"
@onready var deck_opponent: Deck = $DeckOpponent
@onready var combatZones: Array[CombatZone] = [$combatZone, $combatZone2, $combatZone3]
@onready var game_ui: GameUI = $UI
@onready var player_base: PlayerBase = $playerBase
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var card_popup: SubViewport = $cardPopup
@onready var card_in_popup: Card = $cardPopup/Card
var playerControlLock:PlayerControlLock = PlayerControlLock.new()
@onready var graveyard: Graveyard = $graveyard
@onready var extra_deck: CardContainer = $extraDeck
@onready var draw: Button = $UI/draw
@onready var selection_manager: SelectionManager = $SelectionManager
var highlightManager: HighlightManager
# Game data and state management
var game_data: GameData
@onready var graveyard_opponent: Graveyard = $graveyardOpponent

# Opponent AI system
var opponent_ai: OpponentAI

# Casting state tracking
var current_casting_card: Card = null
var casting_card_original_parent: Node = null

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

# Container for castable extra deck cards (displayed to the right of hand)
@onready var extra_deck_display: Node3D = $Camera3D/extra_deck_display

func _ready() -> void:
	# Initialize game data
	game_data = GameData.new()
	game_data.playerDeckList.deck_cards = CardLoaderAL.cardData.duplicate(true)
	game_data.playerDeckList.extra_deck_cards = CardLoaderAL.extraDeckCardData.duplicate(true)
	game_data.opponentDeckList.deck_cards = CardLoaderAL.opponentCards.duplicate(true)
	# Setup UI to follow SignalInt signals
	game_ui.setup_game_data(game_data)
	highlightManager = HighlightManager.new(self)
	
	# Initialize opponent AI
	opponent_ai = OpponentAIScript.new(self)
	
	# Set up payment manager context
	CardPaymentManagerAL.set_game_context(self)
	
	# Initialize selection manager
	selection_manager.selection_cancelled.connect(cancelSelection)
	
	player_control.tryMoveCard.connect(tryMoveCard)
	player_control.rightClick.connect(_on_right_click)
	player_control.leftClick.connect(_on_left_click)
	player_control.cardDragStarted.connect(func(card): if highlightManager: highlightManager.start_card_drag(card))
	player_control.cardDragPositionChanged.connect(func(card, is_outside_hand, pos):
		highlightManager.update_card_drag_position(card, is_outside_hand)
		AnimationsManagerAL.animate_card_dragged(card, pos))
	player_control.cardDragEnded.connect(func(card, is_outside_hand, targetLocation): 
		highlightManager.end_card_drag(card)
		if is_outside_hand:
			tryPlayCard(card, targetLocation))
	draw.pressed.connect(onTurnStart)
	
	populate_decks()
	
	drawCard()
	drawCard()
	drawCard()
	drawCard()
	drawCard()
	drawCard(false)
	drawCard(false)
	drawCard(false)
	onTurnStart(true)

func populate_decks():
	refilLDeck(deck, game_data.playerDeckList.deck_cards.duplicate(true), true)
	refilLDeck(extra_deck, game_data.playerDeckList.extra_deck_cards.duplicate(true), true)
	refilLDeck(deck_opponent, game_data.opponentDeckList.deck_cards.duplicate(true), false)

func onTurnStart(skipFirstTurn = false):
	# Start a new turn (increases danger level via SignalInt)
	if skipFirstTurn:
		game_data.start_new_turn()
		await resolveCombats()
	drawCard()
	@warning_ignore("integer_division")
	for i in range(0, game_data.danger_level.getValue()/3):
		drawCard(false)
	game_data.setOpponentGold()
	await opponent_ai.execute_main_phase()

func tryMoveCard(card: Card, target_location: Node3D) -> void:
	"""Attempt to move a card to the specified location - handles different movement types based on source zone"""
	if not target_location or not card:
		return
	
	var source_zone = getCardZone(card)
	var _target_zone = _getTargetZone(target_location)
	
	match source_zone:
		GameZone.e.HAND, GameZone.e.EXTRA_DECK:
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
	
	# Only process additional selections if playing from hand or extra deck
	if source_zone == GameZone.e.HAND or source_zone == GameZone.e.EXTRA_DECK:
		# Move card to cast preparation position to show casting has started
		AnimationsManagerAL.move_card_to_cast_preparation_position(card)
		
		# Collect all required player selections upfront
		var selection_data = await _collectAllPlayerSelections(card)
		
		# If any selection was cancelled, abort the play
		if selection_data.cancelled:
			print("❌ Selection was cancelled")
			return
		
		# Execute the card play with all collected selections
		await _executeCardPlayWithSelections(card, source_zone, target_location, selection_data)
	else:
		# For cards already in play (like attacks), use simplified execution
		var target_zone = _getTargetZone(target_location)
		await _executeCardPlay(card, source_zone, target_zone, target_location, [])
	
	# If target was combat location, also execute the attack
	if target_location is CombatantFightingSpot:
		await executeCardAttacks(card, target_location as CombatantFightingSpot)
	arrange_cards_fan(true)
	arrange_cards_fan(false)

func _canPlayCard(card: Card, source_zone: GameZone.e, target_location: Node3D) -> bool:
	"""Check if the card can be played to the target location"""
	# Can play cards from hand or extra deck
	var can_play_from_zone = (source_zone == GameZone.e.HAND) or (source_zone == GameZone.e.EXTRA_DECK)
	if not can_play_from_zone:
		return false
	
	# Basic playability check
	if not isCardPlayable(card):
		print("❌ Card not playable!")
		return false
	
	# Check target location availability
	if target_location is CombatantFightingSpot:
		var combat_spot = target_location as CombatantFightingSpot
		if combat_spot.getCard() != null:
			# TODO: Add fallback to next available spot or PlayerBase
			return false
	
	return true

func _getTargetZone(target_location: Node3D) -> GameZone.e:
	"""Determine the game zone for the target location"""
	return GameUtility._getTargetZone(target_location)

func _executeCardPlay(card: Card, source_zone: GameZone.e, _target_zone: GameZone.e, _target_location: Node3D, spell_targets: Array):
	"""Execute the card play with pre-selected spell targets"""
	# If playing from extra deck, remove the card from the extra deck data structure
	if source_zone == GameZone.e.EXTRA_DECK:
		if card.cardData:
			extra_deck.remove_card(card.cardData)
	
	# Trigger CARD_PLAYED action first (before the card moves)
	var played_action = GameAction.new(TriggerType.Type.CARD_PLAYED, card, source_zone, GameZone.e.PLAYER_BASE)
	AbilityManagerAL.triggerGameAction(self, played_action)
	
	# Handle spells differently - they cast their effects then go to graveyard
	if card.cardData.hasType(CardData.CardType.SPELL):
		await _executeSpellWithTargets(card, spell_targets)
		# Move spell to graveyard after effects resolve
		putInOwnerGraveyard(card)
	else:
		# Non-spell cards enter the battlefield normally
		await executeCardEnters(card, source_zone, GameZone.e.PLAYER_BASE)

func _executeSpellWithTargets(card: Card, targets: Array):
	"""Execute spell effects with pre-selected targets"""
	if not card.cardData.hasType(CardData.CardType.SPELL):
		print("❌ Tried to execute spell effects on non-spell card: ", card.cardData.cardName)
		return
	
	print("✨ Casting spell: ", card.cardData.cardName)
	
	# Get spell effects from the card's abilities
	var spell_effects = []
	for ability in card.cardData.abilities:
		if ability.get("type") == "SpellEffect":
			spell_effects.append(ability)
	
	if spell_effects.is_empty():
		print("⚠️ Spell has no effects to execute: ", card.cardData.cardName)
		return
	
	# Execute each spell effect with targets
	var target_index = 0
	for effect in spell_effects:
		var effect_targets = []
		
		# Assign targets to effects that need them
		var effect_type = effect.get("effect_type", "")
		if effect_type == "DealDamage" and target_index < targets.size():
			effect_targets = [targets[target_index]]
			target_index += 1
		
		await _executeSpellEffectWithTargets(card, effect, effect_targets)
	
	print("✨ Finished casting spell: ", card.cardData.cardName)

func _executeSpellEffectWithTargets(card: Card, effect: Dictionary, targets: Array):
	"""Execute a single spell effect with pre-selected targets"""
	var effect_type = effect.get("effect_type", "")
	var parameters = effect.get("parameters", {})
	
	match effect_type:
		"DealDamage":
			await _executeSpellDamageWithTargets(card, parameters, targets)
		_:
			print("❌ Unknown spell effect type: ", effect_type)

func _executeSpellDamageWithTargets(card: Card, parameters: Dictionary, targets: Array):
	"""Execute spell damage effect with pre-selected targets"""
	var damage_amount = parameters.get("NumDamage", 1)
	
	if targets.is_empty():
		print("⚠️ No targets provided for damage spell: ", card.cardData.cardName)
		return
	
	var target = targets[0]
	print("⚡ ", card.cardData.cardName, " deals ", damage_amount, " damage to ", target.cardData.cardName)
	
	# Apply damage
	target.receiveDamage(damage_amount)
	
	# Show damage animation
	AnimationsManagerAL.show_floating_text(self, target.global_position, "-" + str(damage_amount), Color.RED)
	
	# Resolve state-based actions after damage
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
	"""Move card to PlayerBase with smooth animation from current position"""
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:  # No empty location available
		return false
	
	# Convert local position to global position
	var global_target = player_base.global_position + target_position + Vector3(0, 0.1, 0)
	
	# Use the enhanced animate_card_to_position with reparenting
	await AnimationsManagerAL.animate_card_to_position(card, global_target, player_base)
	return true

func drawCard(player = true):
	var _deck = deck if player else deck_opponent
	var _hand = player_hand if player else opponent_hand
	var card = _deck.draw_card_from_top()
	if card == null:
		return
	card.reparent(_hand, false)
	card.makeSmall()
	
	# Trigger card drawn action
	var action = GameAction.new(TriggerType.Type.CARD_DRAWN, card, GameZone.e.DECK, GameZone.e.HAND)
	AbilityManagerAL.triggerGameAction(self, action)
	
	arrange_cards_fan()
	arrange_cards_fan(false)
	# Resolve state-based actions after drawing card
	resolveStateBasedAction()

func arrange_cards_fan(isPlayerHand = true):
	var hand = player_hand if isPlayerHand else opponent_hand
	var cards = hand.get_children()
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
		card.position = Vector3(start_x + spacing * i, 0, 0)

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
	
	var player_strength = combatZone.getTotalStrengthForSide(true)
	var opponent_strength = combatZone.getTotalStrengthForSide(false)
	
	if player_strength > opponent_strength:
		AnimationsManagerAL.show_floating_text(self, combatZone.global_position, "+1 Point", Color.GREEN)
		var _current_points = game_ui.player_point.text.to_int() if game_ui.player_point else 0
		game_data.add_player_points(1)
	elif player_strength < opponent_strength:
		AnimationsManagerAL.show_floating_text(self, combatZone.global_position, "-1 Life", Color.RED)
		game_data.damage_player(1)
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
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	if game_data.player_points.getValue() >= 6:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	
	# Check and highlight castable cards
	updateDecks()
	highlightCastableCards()

func updateDecks():
	if deck.get_card_count() <= game_data.playerDeckList.deck_cards.size():
		refilLDeck(deck, game_data.playerDeckList.deck_cards.duplicate(true), true)
	
	if deck_opponent.get_card_count() <= game_data.opponentDeckList.deck_cards.size():
		refilLDeck(deck_opponent, game_data.opponentDeckList.deck_cards.duplicate(true), false)

func refilLDeck(deckToRefill: CardContainer, cards: Array[CardData], isPlayerOwned: bool):
	for c:CardData in cards:
		c.playerControlled = isPlayerOwned
		c.playerOwned = isPlayerOwned
	cards.shuffle()
	deckToRefill.add_cards(cards)
	
func opponentMainOne():
	"""Delegate to OpponentAI for opponent's main phase logic"""
	if opponent_ai:
		await opponent_ai.execute_main_phase()
	else:
		print("⚠️ OpponentAI not initialized")

func getAllCardsInPlay() -> Array[Card]:
	return GameUtility.getAllCardsInPlay(self) 

func putInOwnerGraveyard(cards):
	"""Move cards to graveyard with parallel animations - accepts both single Card and Array[Card]"""
	var cards_array: Array[Card] = []
	
	# Handle both single cards and arrays
	if cards is Card:
		cards_array = [cards]
	elif cards is Array:
		cards_array = cards
	else:
		print("❌ putInOwnerGraveyard: Invalid input type, expected Card or Array[Card]")
		return
	
	if cards_array.is_empty():
		return
	
	# Start all animations simultaneously and collect their tweens
	var tweens = []
	for card in cards_array:
		if card and is_instance_valid(card):
			card.reparent(self)
			var tween = await AnimationsManagerAL.animate_card_to_position(card, graveyard.global_position)
			if tween:
				tweens.append(tween)
	
	# Wait for all animations to complete in parallel
	if tweens.size() > 0:
		# Wait for all tweens to finish
		for tween in tweens:
			if tween and tween.is_valid():
				await tween.finished
	
	# Add cards to graveyard and clean up after all animations complete
	for card in cards_array:
		if card and is_instance_valid(card):
			graveyard.add_card(card.cardData)
			card.queue_free()

static var objectCount = 0
static func getObjectCountAndIncrement():
	objectCount +=1
	return objectCount-1
	
func createCardFromData(cardData: CardData, card_type: CardData.CardType = CardData.CardType.CREATURE, player_controlled: bool = true, player_owned: bool = true):
	return GameUtility.createCardFromData(self, cardData, card_type, player_controlled, player_owned)

func createToken(cardData: CardData) -> Card:
	"""Create a token card and execute its enters-the-battlefield effects"""
	return await GameUtility.createToken(self, cardData)

func executeCardEnters(card: Card, source_zone: GameZone.e, target_zone: GameZone.e):
	"""Execute the card entering the battlefield - handles movement and triggers"""
	# Move the card to player base
	var play_successful = await moveCardToPlayerBase(card)
	
	if not play_successful:
		print("❌ Failed to move card to player base")
		return
	
	# Trigger CARD_ENTERS action after the card has moved to battlefield
	var enters_action = GameAction.new(TriggerType.Type.CARD_ENTERS, card, source_zone, target_zone)
	AbilityManagerAL.triggerGameAction(self, enters_action)
	
	# Resolve state-based actions after card enters
	resolveStateBasedAction()

func getCardZone(card: Card) -> GameZone.e:
	"""Determine what zone a card is currently in based on its parent and controller"""
	return GameUtility.getCardZone(self, card)

# Helper functions for finding cards by control/ownership
func getAllPlayerControlledCards() -> Array[Card]:
	"""Get all cards currently controlled by the player"""
	var all_cards = getAllCardsInPlay()
	return all_cards.filter(func(card): return card.is_player_controlled())

func getAllOpponentControlledCards() -> Array[Card]:
	"""Get all cards currently controlled by the opponent"""
	var all_cards = getAllCardsInPlay()
	return all_cards.filter(func(card): return card.is_opponent_controlled())

func getAllPlayerOwnedCards() -> Array[Card]:
	"""Get all cards owned by the player (regardless of who controls them)"""
	var all_cards = getAllCardsInPlay()
	return all_cards.filter(func(card): return card.is_player_owned())

func getAllOpponentOwnedCards() -> Array[Card]:
	"""Get all cards owned by the opponent (regardless of who controls them)"""
	var all_cards = getAllCardsInPlay()
	return all_cards.filter(func(card): return card.is_opponent_owned())

# Game Data Access Functions
func get_game_data() -> GameData:
	"""Get the current game data"""
	return game_data

func is_game_over() -> bool:
	"""Check if the game is over (player defeated)"""
	return game_data and game_data.is_player_defeated()

# Graveyard Helper Functions
func get_player_graveyard() -> Graveyard:
	"""Get the player's graveyard"""
	return graveyard

func get_opponent_graveyard() -> Graveyard:
	"""Get the opponent's graveyard"""
	return graveyard_opponent

func get_graveyard_for_controller(is_player_controlled: bool) -> Graveyard:
	"""Get the appropriate graveyard for a card based on its controller"""
	return GameUtility.get_graveyard_for_controller(self, is_player_controlled)

func get_cards_in_player_graveyard() -> Array[CardData]:
	"""Get all cards in the player's graveyard"""
	return GameUtility.get_cards_in_graveyard(self, true)

func get_cards_in_opponent_graveyard() -> Array[CardData]:
	"""Get all cards in the opponent's graveyard"""
	return GameUtility.get_cards_in_graveyard(self, false)

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

func debug_opponent_state():
	"""Debug function to print current opponent state"""
	if opponent_ai:
		opponent_ai.debug_opponent_state()

func debug_all_opponent_cards():
	"""Debug function to show all opponent cards in play"""
	if opponent_ai:
		opponent_ai.debug_all_opponent_cards()

func debug_graveyards():
	"""Debug function to print graveyard contents"""
	print("=== GRAVEYARDS ===")
	var player_cards = get_cards_in_player_graveyard()
	var opponent_cards = get_cards_in_opponent_graveyard()
	
	print("Player graveyard (", player_cards.size(), " cards):")
	for i in range(player_cards.size()):
		var card = player_cards[i]
		print("  ", i + 1, ". ", card.cardName)
	
	print("Opponent graveyard (", opponent_cards.size(), " cards):")
	for i in range(opponent_cards.size()):
		var card = opponent_cards[i]
		print("  ", i + 1, ". ", card.cardName)
	
	print("===================")

func highlightCastableCards():
	"""Check cards in hand and extra deck for castability and update their display"""
	if highlightManager:
		highlightManager.onHighlight()

# Helper functions for extra deck display (used by HighlightManager)
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
		print("🃏 Creating visual card for: ", card_data.cardName)
		var card_instance = createCardFromData(card_data, CardData.CardType.BOSS)
		
		if card_instance:
			# Add to extra deck display
			card_instance.reparent(extra_deck_display)
			
			# Position the card
			card_instance.position.x = start_x + spacing * i
			card_instance.position.y = 0
			card_instance.position.z = 0
			
			# Make sure it's visible and properly sized
			card_instance.makeSmall()
			
			# Add some visual indication that it's from extra deck (e.g., gold outline)
			# Note: This will be overridden by selection/hover states as they have higher priority
			card_instance.set_outline_color(Color.GOLD)

func cancelSelection():
	"""Handle selection cancellation - called when cancel button is pressed or right-click cancels"""
	
	# Clean up the selection state in SelectionManager
	if selection_manager.is_selecting():
		selection_manager._end_selection()
	
	# Restore casting card to its original location if there was one
	if current_casting_card and casting_card_original_parent:
		current_casting_card.reparent(casting_card_original_parent)
		
		# If the card was in hand, rearrange the hand
		if casting_card_original_parent.name == "PlayerHand":
			arrange_cards_fan()
	
	# Clear casting state
	current_casting_card = null
	casting_card_original_parent = null

func _on_right_click(card: Card):
	"""Handle right-click on a card"""
	# Check if we're in a selection process
	if selection_manager.is_selecting():
		var casting_card = selection_manager.get_casting_card()
		
		# If right-clicked on the casting card, cancel the selection
		if casting_card:
			cancelSelection()
			return
	
	# Normal right-click behavior (show popup)
	showCardPopup(card)

func _on_left_click(objectUnderMouse: Node3D):
	if objectUnderMouse is Card and selection_manager.is_selecting():
		selection_manager.handle_card_click(objectUnderMouse as Card)
	
func showCardPopup(card: Card):
	"""Show popup for a card"""
	if card == null:
		return
	
	# Use the shared popup system with enlarged mode and left-side positioning
	if player_control.card_popup_manager and player_control.card_popup_manager.has_method("show_card_popup"):
		var popup_position = _calculate_game_popup_position()
		player_control.card_popup_manager.show_card_popup(card, popup_position, CardPopupManager.DisplayMode.ENLARGED)

func _calculate_game_popup_position() -> Vector2:
	"""Calculate the position for card popup in game view (left side of screen)"""
	return GameUtility._calculate_game_popup_position(self)

# Check if a card matches the selection requirement
func _card_matches_requirement(card: Card, requirement: Dictionary) -> bool:
	return GameUtility._card_matches_requirement(card, requirement)

func start_card_selection(requirement: Dictionary, possible_cards: Array[Card], selection_type: String, casting_card: Card = null) -> Array[Card]:
	# If we have a casting card, set up animation and state tracking
	if casting_card:
		current_casting_card = casting_card
		casting_card_original_parent = casting_card.get_parent()
		await AnimationsManagerAL.move_card_to_casting_position(casting_card)
	
	# Start the selection process
	var selected_cards = await selection_manager.start_selection_and_wait(requirement, possible_cards, selection_type, self, casting_card)
	
	# Clear casting state when selection completes (successfully or cancelled)
	if casting_card:
		current_casting_card = null
		casting_card_original_parent = null
	
	return selected_cards

func _requiresPlayerSelection(additional_costs: Array[Dictionary]) -> bool:
	"""Check if any additional costs require player selection (like sacrifice)"""
	return GameUtility._requiresPlayerSelection(additional_costs)

func _collectAllPlayerSelections(card: Card) -> Dictionary:
	"""Collect all required player selections for a card before playing it"""
	var selection_data = {
		"additional_cost_selections": [] as Array[Card],
		"spell_targets": [] as Array[Card],
		"cancelled": false
	}
	
	# Step 1: Check for additional costs that require selection
	if card.cardData.hasAdditionalCosts():
		var additional_costs = card.cardData.getAdditionalCosts()
		if _requiresPlayerSelection(additional_costs):
			var selected_cards = await _startAdditionalCostSelection(card, additional_costs)
			if selected_cards.is_empty():
				selection_data.cancelled = true
				return selection_data
			selection_data.additional_cost_selections = selected_cards
	
	# Step 2: Check if spell requires targeting
	if card.cardData.hasType(CardData.CardType.SPELL):
		var spell_targets = await _getSpellTargetsIfRequired(card)
		if spell_targets == null:  # null means selection was cancelled
			selection_data.cancelled = true
			return selection_data
		selection_data.spell_targets = spell_targets
	
	return selection_data

func _getSpellTargetsIfRequired(card: Card) -> Variant:
	"""Get spell targets if the spell requires targeting, returns null if cancelled"""
	# Get spell effects that require targeting
	var targeting_effects = []
	for ability in card.cardData.abilities:
		if ability.get("type") == "SpellEffect":
			var effect_type = ability.get("effect_type", "")
			if effect_type == "DealDamage":  # Add other targeting effects here
				targeting_effects.append(ability)
	
	if targeting_effects.is_empty():
		return []  # No targeting required
	
	# For now, handle the first targeting effect
	# TODO: Handle multiple targeting effects
	var effect = targeting_effects[0]
	var parameters = effect.get("parameters", {})
	var valid_targets = parameters.get("ValidTargets", "Any")
	
	# Get all possible targets based on ValidTargets
	var possible_targets: Array[Card] = []
	
	match valid_targets:
		"Any":
			possible_targets = getAllCardsInPlay()
		"Creature":
			for target_card in getAllCardsInPlay():
				if target_card.cardData.hasType(CardData.CardType.CREATURE):
					possible_targets.append(target_card)
		_:
			print("❌ Unknown target type: ", valid_targets)
			return []
	
	if possible_targets.is_empty():
		print("⚠️ No valid targets for ", card.cardData.cardName)
		return []
	
	# Start target selection
	var requirement = {
		"valid_card": "Any",  # We've already filtered the possible_targets
		"count": 1
	}
	
	var selected_targets = await start_card_selection(requirement, possible_targets, "spell_target_" + card.cardData.cardName, card)
	
	if selected_targets.is_empty():
		return null  # Selection was cancelled
	
	return selected_targets

func _executeCardPlayWithSelections(card: Card, source_zone: GameZone.e, target_location: Node3D, selection_data: Dictionary):
	"""Execute card play with all selections already collected"""
	# Validate that the card is still valid
	if not card or not is_instance_valid(card) or not card.cardData:
		print("❌ Card is invalid or freed")
		return
	
	# Pay costs first
	var additional_cost_cards: Array[Card] = selection_data.additional_cost_selections
	
	# Validate additional cost cards are still valid before payment
	var valid_additional_cards: Array[Card] = []
	for cost_card in additional_cost_cards:
		if cost_card and is_instance_valid(cost_card) and cost_card.cardData:
			valid_additional_cards.append(cost_card)
		else:
			print("⚠️ Skipping invalid additional cost card")
	
	var payment_successful = await CardPaymentManagerAL.tryPayCard(card, valid_additional_cards)
	
	if not payment_successful:
		print("❌ Failed to pay for card")
		return
	
	# Determine target zone and execute the play
	var target_zone = _getTargetZone(target_location)
	var spell_targets: Array[Card] = selection_data.spell_targets if selection_data.spell_targets != null else []
	
	# Validate spell targets are still valid
	var valid_spell_targets: Array[Card] = []
	for target_card in spell_targets:
		if target_card and is_instance_valid(target_card) and target_card.cardData:
			valid_spell_targets.append(target_card)
		else:
			print("⚠️ Skipping invalid spell target")
	
	await _executeCardPlay(card, source_zone, target_zone, target_location, valid_spell_targets)

func _startAdditionalCostSelection(card: Card, additional_costs: Array[Dictionary]) -> Array[Card]:
	"""Start the selection process for paying additional costs and return selected cards"""
	
	# For now, handle only the first cost that requires selection
	# TODO: Handle multiple costs in sequence
	for cost_data in additional_costs:
		var cost_type = cost_data.get("cost_type", "")
		if cost_type == "SacrificePermanent":
			var required_count = cost_data.get("count", 1)
			var valid_card_filter = cost_data.get("valid_card", "Card")
			
			# Create selection requirement
			var requirement = {
				"valid_card": valid_card_filter,
				"count": required_count
			}
			
			# Find all possible cards based on the requirement
			var possible_cards: Array[Card] = []
			
			# Get all cards in play (combat zones and player base)
			for check_card in getAllCardsInPlay():
				if _card_matches_requirement(check_card, requirement):
					possible_cards.append(check_card)
			
			# Start the selection process and await completion
			if possible_cards.size() > 0:
				var selected_cards = await start_card_selection(requirement, possible_cards, "sacrifice_for_" + card.cardData.cardName, card)
				return selected_cards
			else:
				print("❌ No valid cards found for selection: ", requirement)
				return []
	
	return []
	
	
func getControllerCards(playerSide = true) -> Array[Card]:
	"""Get all cards the player currently controls (in play)"""
	return GameUtility.getControllerCards(self, playerSide)
