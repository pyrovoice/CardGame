extends Node3D
class_name Game

const OpponentAIScript = preload("res://Game/scripts/OpponentAI.gd")

# Game event signals for triggered abilities to listen to
signal card_entered_play(card_data: CardData)
signal card_died(card_data: CardData)
signal attack_declared(combat_zone: CombatZone)
signal damage_dealt(source_card_data: CardData, target_card_data: CardData, amount: int)
signal spell_cast(card_data: CardData)
signal beginning_of_turn(card_data: CardData)
signal end_of_turn(card_data: CardData)
signal card_drawn(cards: Array, is_player: bool)
signal card_changed_zones(card_data: CardData, from_zone: Node, to_zone: Node)
signal strike(card_data: CardData)

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: CardHand = $PlayerHand
@onready var extra_hand: CardHand = $ExtraHand
@onready var opponent_hand: CardHand = $OpponentHand
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
@onready var admin_button: Button = $UI/AdminButton
@onready var selection_manager: SelectionManager = $SelectionManager
var highlightManager: HighlightManager

# Trigger queue for managing triggered abilities
var trigger_queue: ResolvableQueue = ResolvableQueue.new()
var is_resolving_triggers: bool = false  # Track if we're currently resolving the trigger queue

# MVC Architecture
var game_data: GameData  # Model: Single source of truth for game state
var game_view: GameView  # View: Manages all visual representations

@onready var graveyard_opponent: Graveyard = $graveyardOpponent
var doStartGame = true
# Opponent AI system
var opponent_ai: OpponentAI
@onready var alternative_cast_choice: Control = $UI/AlternativeCastChoice

# Admin console management
@onready var admin_scene: AdminConsole = $UI/AdminScene

# Active hand for PlayerControl
var activeHand: CardHand

func setActiveHand(hand: CardHand):
	activeHand = hand
	player_control.activeHand = hand


# Casting state tracking
var current_casting_card: Card = null
var casting_card_original_parent: Node = null

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

func createCardDatas(card_data_templates: Array[CardData]) -> Array[CardData]:
	var new:Array[CardData] = []
	for c in card_data_templates:
		new.push_back(createCardData(c))
	return new
	
func createCardData(card_data_template: CardData) -> CardData:
	"""Create a new CardData by duplicating a template and registering its abilities to game signals"""
	var new_card_data = CardLoaderAL.duplicateCardScript(card_data_template)
	print("🔍 [CREATEDATA] After duplicateCardScript - ", new_card_data.cardName, " isTapped: ", new_card_data.isTapped)
	
	# Subscribe card data to game signals (registers all abilities and signal listeners)
	new_card_data.subscribe_to_game_signals(self)
	
	return new_card_data

func _ready() -> void:
	# Initialize MVC architecture
	# Model: Game state and data
	game_data = GameData.new()
	
	# View: Visual representation
	game_view = GameView.new()
	add_child(game_view)
	game_view.setup(
		player_hand,
		extra_hand,
		opponent_hand,
		player_base,
		deck,
		deck_opponent,
		extra_deck,
		graveyard,
		graveyard_opponent,
		combatZones
	)
	
	# Initialize activeHand to default player_hand
	activeHand = player_hand
	# Set PlayerControl reference to activeHand
	player_control.activeHand = activeHand
	
	# Load deck configuration from DeckConfig (set by MainMenu or tests)
	if DeckConfigAL.has_deck_configuration():
		game_data.playerDeckList.deck_cards = createCardDatas(DeckConfigAL.player_deck_cards)
		game_data.playerDeckList.extra_deck_cards = createCardDatas(DeckConfigAL.player_extra_deck_cards)
		game_data.opponentDeckList.deck_cards = createCardDatas(DeckConfigAL.opponent_deck_cards)
	else:
		# No deck configuration - leave empty (for tests)
		print("⚠️ No deck configuration found - decks will be empty")
	
	# Setup UI to follow SignalInt signals
	game_ui.setup_game_data(game_data)
	highlightManager = HighlightManager.new(self)
	
	for cz in combatZones:
		var data = CombatLocationData.new(cz)
		game_data.combatLocationDatas.push_back(data)
	
	# Initialize opponent AI
	opponent_ai = OpponentAIScript.new(self)
	
	# Set up payment manager context
	CardPaymentManagerAL.set_game_context(self)
	
	# Initialize selection manager
	selection_manager.selection_cancelled.connect(cancelSelection)
	
	player_control.tryMoveCard.connect(tryMoveCard)
	player_control.rightClick.connect(_on_right_click)
	player_control.leftClick.connect(_on_left_click)
	# Drag handling now done directly by PlayerControl -> CardAnimator
	draw.pressed.connect(onTurnStart)
	admin_button.pressed.connect(func(): admin_scene.show())
	if doStartGame:
		setupGame()
		
func setupGame():
	# Set deck zone names for GameData queries
	deck.zone_name = GameZone.e.DECK_PLAYER
	deck_opponent.zone_name = GameZone.e.DECK_OPPONENT
	extra_deck.zone_name = GameZone.e.EXTRA_DECK_PLAYER
	graveyard.zone_name = GameZone.e.GRAVEYARD_PLAYER
	graveyard_opponent.zone_name = GameZone.e.GRAVEYARD_OPPONENT
	
	populate_decks()
	await drawCard(5, true)
	await drawCard(3, false)
	
	# Debug: Verify MVC state
	print("🎮 [MVC DEBUG] GameData state after setup:")
	game_data.print_game_state()
	
	await onTurnStart(true)
	
func populate_decks():
	# MVC Pattern: Populate both Model (GameData) and View (containers)
	refilLDeck(deck, createCardDatas(game_data.playerDeckList.deck_cards), true, GameZone.e.DECK_PLAYER)
	refilLDeck(deck, createCardDatas(game_data.playerDeckList.deck_cards), true, GameZone.e.DECK_PLAYER)
	refilLDeck(extra_deck, createCardDatas(game_data.playerDeckList.extra_deck_cards), true, GameZone.e.EXTRA_DECK_PLAYER)
	refilLDeck(deck_opponent, createCardDatas(game_data.opponentDeckList.deck_cards), false, GameZone.e.DECK_OPPONENT)

func onTurnStart(skipFirstTurn = false):
	# Start a new turn (increases danger level via SignalInt)
	if !skipFirstTurn:
		await resolve_unresolved_combats()
		# Trigger end of turn phase (cards will clean up their own temporary effects)
		await trigger_phase("EndOfTurn")
		game_data.start_new_turn()
		reset_all_card_turn_tracking()
		# Untap all player cards at start of turn
		untap_all_player_cards()
		game_data.reset_combat_resolution_flags()
		# Trigger beginning of turn phase
		await trigger_phase("BeginningOfTurn")
	await drawCard()
	@warning_ignore("integer_division")
	await drawCard(game_data.danger_level.getValue()/3, false)
	game_data.setOpponentGold()
	await opponent_ai.execute_main_phase()

func execute_move_card(card: Card, destination_zone: GameZone.e, combat_spot: CombatantFightingSpot = null) -> bool:
	"""Centralized zone change system - handles all card movements with appropriate animations and triggers (MVC pattern)
	
	Primary method when you have a Card object. For CardData-based movement (effects), use execute_move_card_from_data().
	
	All costs and selections should be paid/made before calling this.
	Events and triggers fire AFTER animations complete.
	
	Args:
		card: The Card object to move
		destination_zone: Target zone enum (e.g., GameZone.e.GRAVEYARD_PLAYER)
		combat_spot: Optional specific combat spot node (only for combat moves)
	
	Returns:
		bool: True if move was successful, false otherwise
	"""
	if not card:
		push_error("execute_move_card: card is null")
		return false
	
	var card_data = card.cardData
	var origin_zone = card.get_parent()
	var origin_zone_enum = _get_zone_enum(origin_zone)
	
	print("📦 Moving ", card_data.cardName, " from ", GameZone.e.keys()[origin_zone_enum], " to ", GameZone.e.keys()[destination_zone])
	
	# MVC Pattern: Update Model first, then animate View
	# Combat zones handled separately via card_to_combat_spot
	if destination_zone != GameZone.e.COMBAT_PLAYER and destination_zone != GameZone.e.COMBAT_OPPONENT:
		# Get target position from GameView
		var dest_container = game_view.get_zone_container(destination_zone)
		var target_position = dest_container.global_position if dest_container else Vector3.ZERO
		game_data.move_card(card_data, destination_zone, target_position)
	else:
		# Combat: Store spot assignment in GameData
		if combat_spot:
			game_data.assign_card_to_combat_spot(card_data, combat_spot)
	
	# Route to specific movement handlers for animations and triggers
	match [origin_zone_enum, destination_zone]:
		[GameZone.e.DECK_PLAYER, GameZone.e.HAND_PLAYER], [GameZone.e.DECK_OPPONENT, GameZone.e.HAND_OPPONENT]:
			await _move_deck_to_hand(card, destination_zone)
		[_, GameZone.e.BATTLEFIELD_PLAYER], [_, GameZone.e.BATTLEFIELD_OPPONENT]:
			await _move_to_battlefield(card, destination_zone)
		[_, GameZone.e.GRAVEYARD_PLAYER], [_, GameZone.e.GRAVEYARD_OPPONENT]:
			await _move_to_graveyard(card, destination_zone)
		[GameZone.e.BATTLEFIELD_PLAYER, GameZone.e.COMBAT_PLAYER], [GameZone.e.BATTLEFIELD_OPPONENT, GameZone.e.COMBAT_OPPONENT]:
			await _move_base_to_combat(card, destination_zone, combat_spot)
		[GameZone.e.COMBAT_PLAYER, GameZone.e.BATTLEFIELD_PLAYER], [GameZone.e.COMBAT_OPPONENT, GameZone.e.BATTLEFIELD_OPPONENT]:
			await _move_combat_to_base(card, destination_zone)
		_:
			await _move_generic(card, destination_zone)
	
	print("✅ Move complete: ", card_data.cardName)
	return true

func execute_move_card_from_data(card_data: CardData, origin_zone: GameZone.e, destination_zone: GameZone.e, combat_spot: CombatantFightingSpot = null) -> bool:
	"""CardData-based movement - finds or creates Card object then moves it (MVC pattern)
	
	Use this when you only have CardData (e.g., from graveyard/deck effects).
	If you already have a Card object, use execute_move_card() instead.
	
	Args:
		card_data: The CardData to move
		origin_zone: Source zone enum
		destination_zone: Target zone enum
		combat_spot: Optional combat spot (for combat moves)
	
	Returns:
		bool: True if move was successful, false otherwise
	"""
	if not card_data:
		push_error("execute_move_card_from_data: card_data is null")
		return false
	
	# Get origin container from GameView
	var origin_container = game_view.get_zone_container(origin_zone)
	if not origin_container:
		push_error("execute_move_card_from_data: Could not find origin zone container")
		return false
	
	# Find or create the Card object from the origin zone
	var card = _get_card_from_zone(card_data, origin_container)
	if not card:
		push_error("execute_move_card_from_data: Could not find/create card")
		return false
	
	# Use the main Card-based movement method
	return await execute_move_card(card, destination_zone, combat_spot)


func _get_zone_type(container: Node) -> String:
	"""Determine the type of a zone container for routing (legacy string-based)"""
	if container is CardContainer:
		if container == deck or container == deck_opponent:
			return "Deck"
		elif container == graveyard:
			return "Player's Graveyard"
		elif container == graveyard_opponent:
			return "Opponent's Graveyard"
		elif container == extra_deck:
			return "ExtraDeck"
		else:
			return "Container"
	elif container is CardHand:
		return "Hand"
	elif container is PlayerBase:
		return "PlayerBase"
	elif container is CombatantFightingSpot:
		return "Combat"
	else:
		return "Unknown"

func _get_zone_enum(container: Node) -> GameZone.e:
	"""Map a zone container Node to its GameZone.e enum value"""
	if not container:
		return GameZone.e.UNKNOWN
	
	# Check CardContainer types by zone_name if available
	if container is CardContainer and container.zone_name != GameZone.e.UNKNOWN:
		return container.zone_name
	
	# Fall back to manual checking
	if container == player_hand:
		return GameZone.e.HAND_PLAYER
	elif container == opponent_hand:
		return GameZone.e.HAND_OPPONENT
	elif container == player_base:
		return GameZone.e.BATTLEFIELD_PLAYER
	elif container is CombatantFightingSpot:
		# Combat zones - determine owner from spot
		return GameZone.e.COMBAT_PLAYER  # TODO: distinguish player/opponent
	else:
		return GameZone.e.UNKNOWN


func _get_card_from_zone(card_data: CardData, zone_container: Node) -> Card:
	"""Get or create a Card object from a zone for animation"""
	var card: Card = null
	
	if zone_container is CardContainer:
		# Create Card for animation (Card view may not exist yet for container zones)
		# Note: Should check GameData to verify card is actually in this zone
		card = createCardFromData(card_data, card_data.playerControlled, zone_container)
		GameUtility.reparentCardWithoutMovingRepresentation(card, self)
		card.global_position = zone_container.global_position
	elif zone_container is CardHand:
		# Find existing Card in hand
		for c in zone_container.get_children():
			if c is Card and c.cardData == card_data:
				card = c
				GameUtility.reparentCardWithoutMovingRepresentation(card, self)
				break
	elif zone_container is PlayerBase:
		# Find existing Card in PlayerBase
		for c in zone_container.get_children():
			if c is Card and c.cardData == card_data:
				card = c
				GameUtility.reparentCardWithoutMovingRepresentation(card, self)
				break
	elif zone_container is CombatantFightingSpot:
		# Get card from combat spot
		card = zone_container.getCard()
		if card and card.cardData == card_data:
			GameUtility.reparentCardWithoutMovingRepresentation(card, self)
		else:
			card = null
	elif zone_container is Game:
		# Card is parented to game node (e.g., during casting) - search direct children
		for c in zone_container.get_children():
			if c is Card and c.cardData == card_data:
				card = c
				# Already parented to game, no need to reparent
				break
	
	return card

func _move_deck_to_hand(card: Card, dest_zone: GameZone.e):
	"""Handle deck to hand movement - draw animation + trigger (MVC pattern)"""
	# Get visual container from GameView
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_deck_to_hand: Could not find hand container")
		return
	
	# This should use drawCard() for proper multi-card draw animation
	# But for single programmatic draws from effects:
	var origin_pos = card.global_position
	card.setFlip(true)
	
	# Simple draw animation
	var draw_position = Vector3(0, 2, 1)
	var animator = card.getAnimator()
	animator.draw_card(
		origin_pos,
		draw_position,
		dest.global_position,
		0,
		card.cardData.playerControlled and card.is_facedown
	)
	await get_tree().create_timer(0.6).timeout
	
	# Reparent to hand and arrange
	GameUtility.reparentCardWithoutMovingRepresentation(card, dest)
	dest.arrange_cards_fan([card])
	
	# Trigger card_drawn event
	card_drawn.emit([card], card.cardData.playerControlled)

func _move_to_battlefield(card: Card, dest_zone: GameZone.e):
	"""Handle any zone to battlefield - entering play (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	
	# Get visual container from GameView
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_to_battlefield: Could not find battlefield container")
		return
	
	# View: Animate card to battlefield
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:
		push_error("No space on battlefield")
		return
	
	# Use GameView animation
	await game_view.animate_card_to_battlefield(card.cardData, target_position, dest)
	
	# Trigger card entered play
	emit_game_event(TriggeredAbility.GameEventType.CARD_ENTERED_PLAY, card.cardData)
	
	# Apply static and replacement abilities
	for ability in card.cardData.static_abilities:
		ability.apply_to_game(self)
	for ability in card.cardData.replacement_abilities:
		ability.apply_to_game(self)

func _move_to_graveyard(card: Card, dest_zone: GameZone.e):
	"""Handle battlefield/anywhere to graveyard - death (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	
	# Get visual container from GameView
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_to_graveyard: Could not find graveyard container")
		return
	
	# View: Animate to graveyard
	await game_view.animate_card_to_graveyard(card.cardData, dest.global_position)
	
	# Remove battlefield abilities if leaving battlefield
	var origin_zone = card.get_parent()
	var origin_type = _get_zone_type(origin_zone)
	if origin_type == "PlayerBase" or origin_type == "Combat":
		for ability in card.cardData.triggered_abilities:
			ability.unregister_from_game(self)
		for ability in card.cardData.static_abilities:
			ability.remove_from_game(self)
		for ability in card.cardData.replacement_abilities:
			ability.remove_from_game(self)
		
		# Trigger card died
		emit_game_event(TriggeredAbility.GameEventType.CARD_DIED, card.cardData)
	
	# Unsubscribe from game signals
	card.cardData.unsubscribe_from_game_signals(self)
	
	# Remove from parent immediately to prevent card_object reference from being valid
	# queue_free() is deferred, so the card would stay in parent.get_children() otherwise
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	card.queue_free()

func _move_base_to_combat(card: Card, dest_zone: GameZone.e, combat_spot: CombatantFightingSpot):
	"""Handle PlayerBase to Combat - attack movement (MVC pattern)"""
	# Note: GameData already updated by execute_move_card (card_to_combat_spot assigned)
	var origin_zone = card.get_parent()
	
	if not combat_spot:
		push_error("_move_base_to_combat: combat_spot is required")
		return
	
	# View: Animate to combat spot
	game_view.animate_card_to_combat(card.cardData, combat_spot)
	
	# Emit generic zone change
	card_changed_zones.emit(card.cardData, origin_zone, combat_spot)

func _move_combat_to_base(card: Card, dest_zone: GameZone.e):
	"""Handle Combat to PlayerBase - retreat movement (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	var origin_zone = card.get_parent()
	
	# Get visual container from GameView
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_combat_to_base: Could not find battlefield container")
		return
	
	# View: Animate back to base
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:
		return
	
	await game_view.animate_card_to_base(card.cardData, target_position, dest)
	
	# Emit generic zone change
	card_changed_zones.emit(card.cardData, origin_zone, dest)

func _move_generic(card: Card, dest_zone: GameZone.e):
	"""Handle any other zone transitions with generic animation (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	var origin_zone = card.get_parent()
	var origin_type = _get_zone_type(origin_zone)
	
	# Get visual container from GameView
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_generic: Could not find destination container")
		return
	
	# View: Animate to destination
	await game_view.animate_card_move(card.cardData, dest.global_position)
	
	# Handle destination based on type
	if dest is CardContainer:
		# GameData already tracks card in destination zone
		card.queue_free()
	elif dest is CardHand:
		# Reparent to hand and arrange
		GameUtility.reparentCardWithoutMovingRepresentation(card, dest)
		dest.arrange_cards_fan([card])
	elif dest is CombatantFightingSpot:
		game_view.animate_card_to_combat(card.cardData, dest)
	else:
		push_error("_move_generic: Unsupported destination type")
		return
	
	# Remove battlefield abilities if leaving battlefield
	if origin_type == "PlayerBase" or origin_type == "Combat":
		for ability in card.cardData.static_abilities:
			ability.remove_from_game(self)
		for ability in card.cardData.replacement_abilities:
			ability.remove_from_game(self)
	
	# Emit generic zone change trigger
	card_changed_zones.emit(card.cardData, origin_zone, dest)

func tryMoveCard(card: Card, target_location: Node3D) -> void:
	"""Attempt to move a card to the specified location - handles user-initiated movement based on source zone
	
	This method is for USER INPUT (drag/drop, clicks). For programmatic card movement from effects,
	use execute_move_card() instead.
	"""
	if not card:
		return
	
	# Default to PlayerBase if no target specified
	if not target_location:
		target_location = player_base
	
	var source_zone = getCardZone(card)
	
	match source_zone:
		GameZone.e.HAND, GameZone.e.EXTRA_DECK:
			# Playing from hand - use the full play logic
			tryPlayCard(card, target_location)
		
		GameZone.e.PLAYER_BASE:
			await _try_move_from_battlefield(card, target_location)
		
		GameZone.e.COMBAT_ZONE:
			await _try_move_from_combat(card, target_location)

func _try_move_from_battlefield(card: Card, target_location: Node3D) -> void:
	"""Handle user-initiated movement from battlefield to combat"""
	if not target_location is CombatantFightingSpot:
		return
	
	var combat_spot = target_location as CombatantFightingSpot
	
	# Find empty slot if target is occupied
	if combat_spot.getCard():
		combat_spot = (combat_spot.get_parent() as CombatZone).getFirstEmptyLocation(card.cardData.playerControlled)
	
	if combat_spot == null:
		print("No empty slot found for " + card.name)
		return
	
	# Check if card can move (not tapped)
	if not can_card_move(card):
		return
	
	# Tap the card for movement and mark as attacked
	card.cardData.tap()
	card.cardData.hasAttackedThisTurn = true
	
	# Move using centralized system
	await execute_move_card(card, GameZone.e.COMBAT_PLAYER, combat_spot)

func _try_move_from_combat(card: Card, target_location: Node3D) -> void:
	"""Handle user-initiated movement from combat zone (retreat or swap)"""
	if target_location is PlayerBase:
		# Retreat from combat to base
		if can_card_move(card):
			# Tap card for movement
			card.cardData.tap()
			
			# Move using centralized system
			await execute_move_card(card, GameZone.e.BATTLEFIELD_PLAYER)
	elif target_location is CombatantFightingSpot and \
	card.get_parent().get_parent() == target_location.get_parent():
		# Swapping positions within the same combat zone
		exchange_card_in_spots(card.get_parent(), target_location)
	else:
		print("❌ Cannot move card from combat to that location")

func tryPlayCard(card: Card, target_location: Node3D, pre_selections: SelectionManager.CardPlaySelections = null, pay_cost = true, from_default_zones = true) -> void:
	if not card:
		print("❌ [TRYPLAYCARD] Card is null")
		return
	print("🎮 [TRYPLAYCARD] Attempting to play: ", card.cardData.cardName)
	var source_zone = getCardZone(card)
	print("🎮 [TRYPLAYCARD] Source zone: ", GameZone.e.keys()[source_zone])
	
	if from_default_zones && not _canPlayCard(source_zone):
		print("❌ [TRYPLAYCARD] Cannot play from this zone")
		return
	if pay_cost && not CardPaymentManagerAL.canPayCard(card.cardData):
		print("❌ [TRYPLAYCARD] Cannot pay for card")
		return
	
	print("✅ [TRYPLAYCARD] Passed initial checks, proceeding with card play")
	
	# Use CardPlaySelections directly
	var selection_data: SelectionManager.CardPlaySelections
	if pre_selections != null and pre_selections.has_selections():
		print("🎯 Using pre-specified selections for card play")
		selection_data = pre_selections
	else:
		selection_data = null

	# Only process additional selections if playing from hand or extra deck
	var correct_hand
	if source_zone == GameZone.e.HAND or source_zone == GameZone.e.EXTRA_DECK:
		if card.cardData.playerControlled:
			if source_zone == GameZone.e.HAND:
				correct_hand = player_hand
			elif source_zone == GameZone.e.EXTRA_DECK:
				correct_hand = extra_hand
		else:
			correct_hand = opponent_hand
	current_casting_card = card
	casting_card_original_parent = correct_hand
	
	# Only do casting animations/reparenting for cards from hand/extra deck
	if source_zone == GameZone.e.HAND or source_zone == GameZone.e.EXTRA_DECK:
		GameUtility.reparentCardWithoutMovingRepresentation(card, self)
		
		# Move card to cast preparation position to show casting has started
		await card.getAnimator().cast_position(card.is_facedown).finished
		if !card.cardData.playerControlled:
			await get_tree().create_timer(0.5).timeout
	
	# Collect all required player selections upfront (including casting choice)
	if selection_data == null:
		print("🎮 [TRYPLAYCARD] Calling _collectAllPlayerSelections for ", card.cardData.cardName)
		selection_data = await _collectAllPlayerSelections(card)
	else:
		print("🎯 Skipping selection collection - using pre-specified selections")
	
	# If any selection was cancelled, abort the play
	if selection_data.cancelled:
		_restore_cancelled_card()
		return
	
	# Execute the card play with all collected selections
	await tryPayAndSelectsForCardPlay(card.cardData, source_zone, selection_data, pay_cost)
	
	if target_location is CombatantFightingSpot:
		var combat_spot = target_location as CombatantFightingSpot
		
		# Find empty slot if target is occupied
		if combat_spot.getCard():
			combat_spot = (combat_spot.get_parent() as CombatZone).getFirstEmptyLocation(card.cardData.playerControlled)
		
		if combat_spot:
			# Check if card can be tapped
			if card.cardData.can_tap():
				card.cardData.tap()
				card.cardData.hasAttackedThisTurn = true
				
				await execute_move_card(card, GameZone.e.COMBAT_PLAYER, combat_spot)

func _canPlayCard(source_zone: GameZone.e) -> bool:
	# Can play cards from hand or extra deck
	var can_play_from_zone = (source_zone == GameZone.e.HAND) or (source_zone == GameZone.e.EXTRA_DECK)
	if not can_play_from_zone:
		return false
	return true 
	
func _executeCardPlay(card: Card, source_zone: GameZone.e, spell_targets: Array):
	
	# Handle spells differently - they cast their effects then go to graveyard
	if card.cardData.hasType(CardData.CardType.SPELL):
		await _executeSpellWithTargets(card, spell_targets)
		# Move spell to graveyard after effects resolve using centralized movement system
		var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if card.cardData.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
		await execute_move_card(card, graveyard_zone)
	else:
		# Non-spell cards enter the battlefield normally
		await executeCardEnters(card, source_zone, GameZone.e.PLAYER_BASE)
	await resolveStateBasedAction()

func _executeSpellWithTargets(card: Card, targets: Array):
	if not card.cardData.hasType(CardData.CardType.SPELL):
		print("❌ Tried to execute spell effects on non-spell card: ", card.cardData.cardName)
		return
	
	print("✨ Casting spell: ", card.cardData.cardName)
	
	# Get spell abilities from the card
	var spell_abilities = card.cardData.spell_abilities
	
	if spell_abilities.is_empty():
		print("⚠️ Spell has no effects to execute: ", card.cardData.cardName)
		return
	
	# Execute each spell effect with targets
	var target_index = 0
	for spell_ability in spell_abilities:
		var effect_targets = []
		
		# Assign targets to effects that need them
		if spell_ability.requires_target() and target_index < targets.size():
			effect_targets = [targets[target_index]]
			target_index += 1
		
		await _executeSpellEffectWithTargets(card, spell_ability, effect_targets)
	
	print("✨ Finished casting spell: ", card.cardData.cardName)

func _executeSpellEffectWithTargets(card: Card, spell_ability: SpellAbility, targets: Array):
	# For targeting effects, add targets to parameters
	if targets.size() > 0:
		spell_ability.effect_parameters["Targets"] = targets
	
	# Use the unified ability execution system (pass CardData instead of Card)
	await AbilityManagerAL.executeAbilityEffect(card.cardData, spell_ability, self)

func _executeSpellDamageWithTargets(card: Card, parameters: Dictionary, targets: Array):
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
	await resolveStateBasedAction()

	
	# Emit attack_declared signal for triggered abilities
	attack_declared.emit(card.cardData)
	
	# Resolve state-based actions after attack
	await resolveStateBasedAction()

func drawCard(howMany: int = 1, player = true):
	# MVC Pattern: Query Model → Create Views → Animate Views
	
	var _deck = deck if player else deck_opponent
	var zone_name = GameZone.e.HAND_PLAYER if player else GameZone.e.HAND_OPPONENT
	var deck_zone_name = GameZone.e.DECK_PLAYER if player else GameZone.e.DECK_OPPONENT
	var hand = player_hand if player else opponent_hand
	
	# Store deck position for animations
	var deck_position = _deck.global_position
	
	# Query Model: Get top N cards from GameData deck zone
	var deck_cards = game_data.cards_in_deck_player if player else game_data.cards_in_deck_opponent
	var cards_to_draw = deck_cards.slice(0, min(howMany, deck_cards.size()))
	
	if cards_to_draw.is_empty():
		print("⚠️ No cards to draw from deck")
		return
	
	# Create Card views for each CardData
	var card_views: Array[Card] = []
	for card_data in cards_to_draw:
		# Move from deck to hand in GameData
		game_data.move_card(card_data, zone_name, Vector3.ZERO)
		
		# Create Card view through Game (legacy createCardFromData)
		var card_view = createCardFromData(card_data, player, null)
		card_view.global_position = deck_position
		
		# Register with GameView
		game_view.card_data_to_view[card_data] = card_view
		card_views.append(card_view)
		
		# Add to hand container
		hand.add_child(card_view)
	
	# Update deck visual size
	_deck.update_size()
	
	# Update View: Arrange hand layout
	hand.arrange_cards_fan(card_views)
	
	# Keep all newly added cards' representations at deck position
	for card in card_views:
		card.card_representation.global_position = deck_position
	
	# Animate Views: Draw animation for each card
	var draw_position = Vector3(0, 2, 1)
	for i in range(card_views.size()):
		var card = card_views[i]
		
		# Calculate offset for multiple cards (spread them out during draw)
		var spacing = 0.56
		var offset = Vector3(-(spacing * (card_views.size() - 1)) / 2 + spacing * i, 0, 0)
		var target_draw_pos = draw_position + offset
		
		# Use GameView animation method
		game_view.animate_draw_card(
			card.cardData,
			deck_position,
			card.global_position,  # final position in hand
			i * 0.1,  # delay
			player and card.is_facedown
		)
	
	# Wait for all animations to complete (longest delay + animation time)
	await get_tree().create_timer(card_views.size() * 0.2 + 0.6).timeout
	
	# Emit card_drawn signal for triggered abilities
	card_drawn.emit(card_views, player)
	await resolveStateBasedAction()

func resolveCombats():
	var lock = playerControlLock.addLock()
	for cv in combatZones:
		await resolveCombatInZone(cv)
	playerControlLock.removeLock(lock)

func resolve_unresolved_combats():
	var lock = playerControlLock.addLock()
	for cld in game_data.combatLocationDatas:
		if !cld.isCombatResolved.value:
			await resolve_combat_for_zone(cld.relatedLocation)
	
	playerControlLock.removeLock(lock)

func resolve_combat_for_zone(combat_zone: CombatZone):
	
	# Check if already resolved
	if game_data.is_combat_resolved(combat_zone):
		return
	
	# Resolve this zone's combat
	var lock = playerControlLock.addLock()
	await resolveCombatInZone(combat_zone)
	game_data.set_combat_resolved(combat_zone, true)
	playerControlLock.removeLock(lock)

func reset_all_card_turn_tracking():
	for card in _get_all_player_cards():
		card.cardData.reset_turn_tracking()

func untap_all_player_cards():
	for card in _get_all_player_cards():
		if card.cardData.is_tapped():
			card.cardData.untap()
			print("🔄 Untapped ", card.cardData.cardName)

func _get_all_player_cards() -> Array[Card]:
	var all_cards: Array[Card] = []
	
	# Cards in hand
	for child in player_hand.get_children():
		if child is Card:
			all_cards.append(child)
	
	# Cards in player base
	for child in player_base.get_children():
		if child is Card:
			all_cards.append(child)
	
	# Cards in combat zones
	for zone in combatZones:
		for spot in zone.allySpots:
			var card = spot.getCard()
			if card is Card:
				all_cards.append(card)
	
	return all_cards

func _get_target_zone(target_location: Node3D) -> GameZone.e:
	if target_location is CombatantFightingSpot:
		return GameZone.e.COMBAT_ZONE
	elif target_location is PlayerBase:
		return GameZone.e.PLAYER_BASE
	elif target_location == player_hand:
		return GameZone.e.HAND
	else:
		return GameZone.e.UNKNOWN
	
func resolveCombatInZone(combatZone: CombatZone):
	print("🔥 === Resolving Combat in Zone ===")
	
	# Step 1: Mark all attacking cards as having attacked
	for slot_index in range(1, 4):
		var player_card = combatZone.getCardSlot(slot_index, true).getCard()
		if player_card:
			player_card.cardData.hasAttackedThisTurn = true
			print("⚔️ ", player_card.cardData.cardName, " is attacking")
	
	# Step 2: Trigger attack declared once for the combat location (before fights)
	attack_declared.emit(combatZone)
	await resolve_queue()
	
	# Step 3: Resolve each slot's combat
	for slot_index in range(1, 4):
		var player_card = combatZone.getCardSlot(slot_index, true).getCard()
		var opponent_card = combatZone.getCardSlot(slot_index, false).getCard()
		
		if not player_card and not opponent_card:
			continue
		
		var player_damage = player_card.getPower() if player_card else 0
		var opponent_damage = opponent_card.getPower() if opponent_card else 0
		
		# Combat strike animations and damage
		if player_card and opponent_card:
			# Both cards strike each other
			player_card.getAnimator().animate_combat_strike(opponent_card)
			opponent_card.getAnimator().animate_combat_strike(player_card)
			
			# Emit strike events for triggered abilities
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, player_card.cardData)
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, opponent_card.cardData)
			player_card.receiveDamage(opponent_damage)
			opponent_card.receiveDamage(player_damage)
		elif player_card and not opponent_card:
			# Player attacks location directly
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, player_card.cardData)
			_apply_damage_to_location(player_damage, true, combatZone)
		elif opponent_card and not player_card:
			# Opponent attacks location directly
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, opponent_card.cardData)
			_apply_damage_to_location(opponent_damage, false, combatZone)
	
	await resolveStateBasedAction()
	resolve_queue()

func _apply_damage_to_location(damage: int, is_player_damage: bool, combatZone: CombatZone):
	if damage <= 0:
		return
	game_data.add_location_capture_value(damage, is_player_damage, combatZone)
	
	# Show floating text animation
	var damage_text = "+" + str(damage) + " Capture"
	var damage_color = Color.BLUE if is_player_damage else Color.RED
	AnimationsManagerAL.show_floating_text(self, combatZone.global_position, damage_text, damage_color)

func _check_locations_capture():
	for combatZone in combatZones:
		var data = game_data.get_combat_zone_data(combatZone)
		if data.opponent_capture_current.value >= data.opponent_capture_threshold.value:
			_handle_location_captured(combatZone, false)
		elif data.player_capture_current.value >= data.player_capture_threshold.value:
			_handle_location_captured(combatZone, true)

func _handle_location_captured(combatZone: CombatZone, captured_by_player: bool):
	var capture_text = combatZone.name + " CAPTURED!"
	var capture_color = Color.GOLD if captured_by_player else Color.PURPLE
	AnimationsManagerAL.show_floating_text(self, combatZone.global_position, capture_text, capture_color)
	
	if captured_by_player:
		game_data.add_player_points(1)
		game_data.get_combat_zone_data(combatZone).player_capture_threshold.value += 5
	else:
		game_data.damage_player(1)
		game_data.add_gold(1)
		game_data.get_combat_zone_data(combatZone).opponent_capture_threshold.value += 5
		
	game_data.reset_combat_zone_data(combatZone)

func resolveStateBasedAction():
	# Query GameData for all cards in play (MVC pattern)
	var cards_in_play_data = game_data.get_cards_in_play()
	print("🔍 [SBA] Checking ", cards_in_play_data.size(), " cards in play for state-based actions")
	
	for card_data in cards_in_play_data:
		# Get the Card node for this CardData
		var c = card_data.get_card_object()
		
		# Skip cards that don't have a valid Card node (already freed or moved)
		if not c or not is_instance_valid(c):
			print("  ⚠️ [SBA] Skipping invalid card node for ", card_data.cardName)
			continue
			
		var damage = c.getDamage()
		var power = c.getPower()
		
		if damage > 0 && damage >= power:
			print("  💀 [SBA] ", card_data.cardName, " is dead (damage: ", damage, " >= power: ", power, "), moving to graveyard")
			var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
			await execute_move_card(c, graveyard_zone)
			print("  ✅ [SBA] Finished moving ", card_data.cardName if is_instance_valid(c) else "[freed card]", " to graveyard")
	if game_data.player_life.getValue() <= 0:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	if game_data.player_points.getValue() >= 6:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	_check_locations_capture()
	# Check and highlight castable cards
	updateDecks()
	highlightCastableCards()

func updateDecks():
	# Query GameData instead of CardContainer for card counts
	if game_data.cards_in_deck_player.size() <= game_data.playerDeckList.deck_cards.size():
		refilLDeck(deck, createCardDatas(game_data.playerDeckList.deck_cards), true, GameZone.e.DECK_PLAYER)
	
	if game_data.cards_in_deck_opponent.size() <= game_data.opponentDeckList.deck_cards.size():
		refilLDeck(deck_opponent, createCardDatas(game_data.opponentDeckList.deck_cards), false, GameZone.e.DECK_OPPONENT)

func refilLDeck(deckToRefill: CardContainer, cards: Array[CardData], isPlayerOwned: bool, zone_name: GameZone.e):
	# MVC Pattern: Update Model (GameData only)
	for c:CardData in cards:
		c.playerOwned = isPlayerOwned
		# Add to GameData model (no need to track in container)
		game_data.add_card_to_zone(c, zone_name, deckToRefill.global_position)
	cards.shuffle()
	
func opponentMainOne():
	if opponent_ai:
		await opponent_ai.execute_main_phase()
	else:
		print("⚠️ OpponentAI not initialized")

static var objectCount = 0
static func getObjectCountAndIncrement():
	objectCount +=1
	return objectCount-1

## MVC Pattern: Create card view through GameView
func create_card_view_mvc(card_data: CardData, is_player_controlled: bool, zone: GameZone.e) -> Card:
	"""Create a Card view using MVC pattern - Model → View"""
	# Model: Add to GameData
	game_data.add_card_to_zone(card_data, zone, Vector3.ZERO)
	
	# View: Create Card node
	var card = game_view.create_card_view(card_data, is_player_controlled, false)
	
	# Get zone container and add card to it
	var zone_container = game_view.get_zone_container(zone)
	if zone_container:
		zone_container.add_child(card)
	
	return card
	
## Legacy: Old card creation (to be phased out)
func createCardFromData(cardData: CardData, player_controlled: bool, container: CardContainer = null):
	# TODO: Migrate callers to use create_card_view_mvc instead
	return GameUtility.createCardFromData(self, cardData, player_controlled, false, container)

func createToken(cardData: CardData, player_controlled: bool) -> Card:
	return GameUtility.createCardFromData(self, cardData, player_controlled, true, null)

func playCardFromDeck(card_data: CardData):
	# MVC Pattern: Query GameData → Create View → Execute play
	
	# Check if card exists in GameData deck zone
	var deck_zone_name = GameZone.e.DECK_PLAYER if card_data.playerControlled else GameZone.e.DECK_OPPONENT
	var deck_cards = game_data.cards_in_deck_player if card_data.playerControlled else game_data.cards_in_deck_opponent
	
	if not deck_cards.has(card_data):
		print("❌ Card not found in deck: ", card_data.cardName)
		return
	
	# Create Card view from CardData (will be moved to battlefield)
	var card = createCardFromData(card_data, card_data.playerControlled, null)
	game_view.card_data_to_view[card_data] = card
	
	# Execute card entering from deck to battlefield
	await executeCardEnters(card, GameZone.e.DECK, GameZone.e.PLAYER_BASE)
	print("✅ Card played from deck successfully: ", card_data.cardName)

func executeCardEnters(card: Card, source_zone: GameZone.e, target_zone: GameZone.e):
	"""Execute card entering the battlefield - uses Card object directly for user-played cards"""
	if not card:
		push_error("executeCardEnters called with null card")
		return
	
	# For user-played cards, the Card object already exists but may not be in a proper zone
	# We handle the battlefield entry directly here instead of using execute_move_card
	var dest_zone = player_base
	
	# Set flip and size
	card.setFlip(true)
	card.getAnimator().make_small()
	
	# Reparent to battlefield
	GameUtility.reparentCardWithoutMovingRepresentation(card, dest_zone)
	
	# Animate to battlefield
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:
		push_error("No space on battlefield")
		return
	
	var local_target = target_position + Vector3(0, 0.2, 0)
	var tween = card.getAnimator().move_to_position(local_target, 0.8, dest_zone)
	if tween:
		await tween.finished
	
	# Trigger card entered play
	emit_game_event(TriggeredAbility.GameEventType.CARD_ENTERED_PLAY, card.cardData)
	
	# Apply static and replacement abilities
	for ability in card.cardData.static_abilities:
		ability.apply_to_game(self)
	for ability in card.cardData.replacement_abilities:
		ability.apply_to_game(self)
	
	# Resolve state-based actions after card enters
	await resolveStateBasedAction()

func getCardZone(card: Card) -> GameZone.e:
	return GameUtility.getCardZone(self, card)

func get_highlight_manager() -> HighlightManager:
	return highlightManager

func connect_card_to_highlight_manager(card: Card):
	if highlightManager:
		highlightManager.connect_to_card_animator(card)

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

func highlightCastableCards():
	"""Check cards in hand and extra deck for castability and update their display"""
	if highlightManager:
		highlightManager.onHighlight()
	
	# Update extra deck outline based on castable cards
	_updateExtraDeckOutline()

func _updateExtraDeckOutline():
	"""Update extra deck outline visibility based on whether there are castable cards"""
	var has_castable_cards = false
	
	for card_data: CardData in extra_deck.cards:
		if CardPaymentManagerAL.isCardDataCastable(card_data):
			has_castable_cards = true
			break
	
	if has_castable_cards:
		extra_deck.get_node("MeshInstance3D/Outline").show()
	else:
		extra_deck.get_node("MeshInstance3D/Outline").hide()


func _toggleExtraDeckView():
	if extra_hand.visible:
		extra_hand.hide()
		player_hand.show()
		setActiveHand(player_hand)
	elif extra_deck.outline.visible:
		player_hand.hide()
		extra_hand.show()
		setActiveHand(extra_hand)
		_extra_deck_hand_arrange()

func _extra_deck_hand_arrange():
	# Show only castable extra deck cards
	var spacing = 0.8  # Horizontal spacing between cards
	var loopC = 0
	
	for c in extra_hand.get_children():
		c.queue_free()
	await get_tree().process_frame
	for card_data: CardData in extra_deck.cards:
		# Only display castable cards
		if CardPaymentManagerAL.isCardDataCastable(card_data):
			# Create a card for display (don't remove from extra_deck)
			var card = createCardFromData(card_data, true)
			GameUtility.reparentCardWithoutMovingRepresentation(card, extra_hand)
			card.setFlip(true)
			
			# Position the card
			card.position.x = spacing * loopC
			card.position.y = 0
			card.position.z = 0
			card.card_representation.position = Vector3.ZERO
			
			card.getAnimator().make_small()
			
			loopC += 1
	extra_hand.arrange_cards_fan()


func _restore_cancelled_card():
	"""Restore casting card to its original location and clean up casting state"""
	if current_casting_card and casting_card_original_parent:
		
		# Reset visual properties before reparenting
		current_casting_card.getAnimator().make_small()
		casting_card_original_parent.arrange_card_fan(current_casting_card)
	
	# Clear casting state
	current_casting_card = null
	casting_card_original_parent = null

func cancelSelection():
	"""Handle UI/interaction cancellation and restore the card"""
	# Clean up the selection state in SelectionManager
	if selection_manager.is_selecting():
		selection_manager._end_selection()
	
	# Restore the casting card using shared logic
	_restore_cancelled_card()

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

func tryActivateAbility(card: Card) -> bool:
	"""Try to activate an activated ability on the card"""
	if not card or not card.cardData:
		return false
	
	# Find activated abilities on the card
	var activated_abilities = card.cardData.activated_abilities
	
	if activated_abilities.is_empty():
		return false
	
	# For now, if there are multiple activated abilities, use the first one
	# TODO: Add UI to choose between multiple abilities
	var ability_to_activate = activated_abilities[0]
	
	# Check if the ability can be activated (costs can be paid)
	if not CardPaymentManagerAL.canPayCosts(ability_to_activate.activation_costs, card.cardData):
		print("⚠️ Cannot pay activation costs for ", card.cardData.cardName)
		return false
	
	print("🔥 Activating ability on ", card.cardData.cardName)
	
	# Activate the ability
	await AbilityManagerAL.activateAbility(card.cardData, ability_to_activate, self)
	
	return true

func _on_left_click(objectUnderMouse):
	if objectUnderMouse is Card:
		var card = objectUnderMouse as Card
		if selection_manager.is_selecting():
			selection_manager.handle_card_click(card)
		else:
			if await tryActivateAbility(card):
				return
	elif objectUnderMouse is ResolveFightButton:
		resolve_combat_for_zone(objectUnderMouse.get_parent())
	elif objectUnderMouse == extra_deck:
		_toggleExtraDeckView()

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

func start_card_selection(requirement: Dictionary, possible_cards: Array[CardData], selection_type: String, casting_card: Card = null, preselected_cards: Array[CardData] = []) -> Array[CardData]:
	# If we have pre-selected cards, use them directly
	if preselected_cards.size() > 0:
		print("🎯 Using pre-selected cards for ", selection_type, ": ", preselected_cards.size(), " cards")
		return preselected_cards
	
	# If we have a casting card, set up animation and state tracking
	if casting_card:
		current_casting_card = casting_card
		# Move to card selection position - using legacy method for now
		await AnimationsManagerAL.animate_card_to_card_selection_position(casting_card)
	
	# SelectionManager now takes CardData arrays and returns CardData arrays
	var selected_cards = await selection_manager.start_selection_and_wait(requirement, possible_cards, selection_type, self, casting_card.card_data if casting_card else null, preselected_cards)
	
	# Clear casting state when selection completes (successfully or cancelled)
	if casting_card:
		current_casting_card = null
		casting_card_original_parent = null
	
	return selected_cards

func _requiresPlayerSelection(additional_costs: Array[Dictionary]) -> bool:
	"""Check if any additional costs require player selection (like sacrifice)"""
	return GameUtility._requiresPlayerSelection(additional_costs)

func _collectAllPlayerSelections(card: Card, pre_selections: SelectionManager.CardPlaySelections = null) -> SelectionManager.CardPlaySelections:
	"""Collect all required player selections for a card before playing it"""
	var selection_data = SelectionManager.CardPlaySelections.new()
	
	# If pre-selections are provided, use them
	if pre_selections != null:
		print("🎯 Using provided pre-selections for card play")
		return pre_selections
	
	# Step 1: Check for alternative casting options (Replace)
	var has_replace = CardPaymentManagerAL.hasReplaceOption(card.cardData)
	print("🔍 [REPLACE CHECK] hasReplaceOption returned: ", has_replace, " for ", card.cardData.cardName)
	if has_replace:
		# Get valid replacement targets for selection
		var replace_cost_data = null
		for cost_data in card.cardData.additionalCosts:
			if cost_data.get("cost_type", "") == "Replace":
				replace_cost_data = cost_data
				break
		
		if replace_cost_data:
			var valid_targets = CardPaymentManagerAL.getValidReplaceTargets(card.cardData, replace_cost_data)
			if valid_targets.size() > 0:
				# TODO: Show CastChoice.tscn UI here - for now use selection manager
				var requirement = {
					"valid_card": "Any", # Already filtered
					"count": 1,
					"optional": true # Player can choose nothing to cast normally
				}
				
				# Check if we have pre-selected replace target
				var preselected_replace: Array[CardData] = []
				if pre_selections != null and pre_selections.replace_target != null:
					preselected_replace = [pre_selections.replace_target]
				
				var selected_replace_target = await start_card_selection(
					requirement, 
					valid_targets, 
					"replace_for_" + card.cardData.cardName, 
					card,
					preselected_replace
				)
				
				if selected_replace_target == null:
					selection_data.cancelled = true
					return selection_data
				elif selected_replace_target.size() > 0:
					selection_data.set_replace_target(selected_replace_target[0])
	
	# Step 2: Check for additional costs that require selection
	if card.cardData.hasAdditionalCosts():
		var additional_costs = card.cardData.getAdditionalCosts()
		if _requiresPlayerSelection(additional_costs):
			# Check for pre-selected sacrifice target cards
			var preselected_sacrifice: Array[CardData] = []
			if pre_selections != null and pre_selections.sacrifice_targets.size() > 0:
				preselected_sacrifice = pre_selections.sacrifice_targets
			
			var selected_cards = await _startAdditionalCostSelection(card, additional_costs, preselected_sacrifice)
			if selected_cards.is_empty():
				selection_data.cancelled = true
				return selection_data
			for card_selection in selected_cards:
				selection_data.add_sacrifice_target(card_selection)
	
	# Step 3: Check if spell requires targeting
	if card.cardData.hasType(CardData.CardType.SPELL):
		# Check for pre-selected spell targets
		var preselected_spell_targets: Array[CardData] = []
		if pre_selections != null and pre_selections.spell_targets.size() > 0:
			preselected_spell_targets = pre_selections.spell_targets
		
		var spell_targets = await _getSpellTargetsIfRequired(card, preselected_spell_targets)
		if spell_targets == null:  # null means selection was cancelled
			selection_data.cancelled = true
			return selection_data
		# Only check for empty targets if the spell actually requires targeting
		if spell_targets is Array and spell_targets.is_empty() and _spellRequiresTargeting(card):
			print("❌ No valid targets available - cancelling spell")
			selection_data.cancelled = true
			return selection_data
		for target in spell_targets:
			selection_data.add_spell_target(target)
	
	return selection_data

func _spellRequiresTargeting(card: Card) -> bool:
	"""Check if a spell has any effects that require targeting"""
	for ability in card.cardData.spell_abilities:
		if ability.requires_target():
			return true
	return false

func _getSpellTargetsIfRequired(card: Card, preselected_targets: Array[CardData] = []) -> Variant:
	"""Get spell targets if the spell requires targeting, returns null if cancelled"""
	
	# If pre-selected targets are provided, return them
	if preselected_targets.size() > 0:
		print("🎯 Using pre-selected spell targets: ", preselected_targets.map(func(c): return c.cardName))
		return preselected_targets
	
	# Get spell abilities that require targeting
	var targeting_abilities: Array[SpellAbility] = []
	for ability in card.cardData.spell_abilities:
		if ability.requires_target():
			targeting_abilities.append(ability)
	
	if targeting_abilities.is_empty():
		return []  # No targeting required
	
	# For now, handle the first targeting effect
	# TODO: Handle multiple targeting effects
	var spell_ability = targeting_abilities[0]
	var valid_targets = spell_ability.effect_parameters.get("ValidTargets", "Any")
	
	# Query GameData for cards in play (MVC pattern)
	var cards_in_play_data = game_data.get_cards_in_play()
	
	# Filter CardData based on ValidTargets
	var valid_card_data: Array[CardData] = []
	match valid_targets:
		"Any":
			valid_card_data = cards_in_play_data
		"Creature":
			for card_data in cards_in_play_data:
				if card_data.hasType(CardData.CardType.CREATURE):
					valid_card_data.append(card_data)
		_:
			print("❌ Unknown target type: ", valid_targets)
			return []
	
	if valid_card_data.is_empty():
		print("⚠️ No valid targets for ", card.cardData.cardName)
		return []
	
	# Start target selection with CardData
	var requirement = {
		"valid_card": "Any",  # We've already filtered the valid_card_data
		"count": 1
	}
	
	var selected_targets = await start_card_selection(requirement, valid_card_data, "spell_target_" + card.cardData.cardName, card)
	
	if selected_targets.is_empty():
		return null  # Selection was cancelled
	
	return selected_targets

func tryPayAndSelectsForCardPlay(card_data: CardData, source_zone: GameZone.e, selection_data: SelectionManager.CardPlaySelections, pay_cost: bool = true):
	"""Execute card play with all selections already collected"""
	# Validate that the card data is valid
	if not card_data:
		print("❌ CardData is invalid")
		return
	
	# Get the card node for execution
	var card_node = card_data.get_card_object()
	if not card_node or not is_instance_valid(card_node):
		print("❌ Card node is invalid or freed")
		return
	
	# Skip payment if pay_cost is false (e.g., casting from deck via effect)
	if not pay_cost:
		print("💫 Skipping payment for card (cast via effect)")
		await _executeCardPlay(card_node, source_zone, [])
		return
	
	# Pay costs first - selection_data stores CardData
	var sacrifice_targets_data: Array[CardData] = selection_data.sacrifice_targets
	
	# Validate Replace casting choice if selected
	if selection_data.replace_target != null:
		var replace_target_data: CardData = selection_data.replace_target
		
		# Verify the card actually has Replace option
		if not CardPaymentManagerAL.hasReplaceOption(card_data):
			print("❌ Card does not have Replace option")
			return
		
		# Verify the target is valid for Replace
		if not CardPaymentManagerAL.isValidReplaceTarget(card_data, replace_target_data):
			print("❌ Replace target is not valid for this card")
			return
		
		# Verify we can afford the Replace cost
		var replace_cost = CardPaymentManagerAL.calculateReplaceCost(card_data, replace_target_data)
		if not game_data.has_gold(replace_cost, card_data.playerControlled):
			print("❌ Cannot afford Replace cost: ", replace_cost)
			return
	
	# Build selected cards array for payment processing (includes both sacrifice and replace targets)
	var selected_cards_data: Array[CardData] = sacrifice_targets_data.duplicate()
	if selection_data.replace_target != null:
		selected_cards_data.append(selection_data.replace_target)
	
	# Calculate payment requirements using CardPaymentManager
	var payment_info = CardPaymentManagerAL.tryPayCard(card_data, selected_cards_data)
	if not payment_info.success:
		print("❌ Failed to calculate payment for card")
		return
	
	# Execute payment: spend gold
	if not game_data.spend_gold(payment_info.gold_cost, card_data.playerControlled):
		print("❌ Failed to spend gold")
		return
	
	# Execute payment: sacrifice cards (game.gd handles movement)
	for sacrifice_card_data in payment_info.cards_to_sacrifice:
		var sacrifice_card_node = sacrifice_card_data.get_card_object()
		if sacrifice_card_node and is_instance_valid(sacrifice_card_node):
			var dest_zone = GameZone.e.GRAVEYARD_PLAYER if sacrifice_card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
			await execute_move_card(sacrifice_card_node, dest_zone)
		else:
			print("⚠️ Skipping invalid sacrifice target")
	
	# Convert spell targets from CardData to Card nodes for execution
	var spell_targets_data: Array[CardData] = selection_data.spell_targets
	var valid_spell_targets: Array[Card] = []
	for target_data in spell_targets_data:
		if target_data:
			var target_node = target_data.get_card_object()
			if target_node and is_instance_valid(target_node):
				valid_spell_targets.append(target_node)
			else:
				print("⚠️ Skipping invalid spell target")
	
	await _executeCardPlay(card_node, source_zone, valid_spell_targets)

func _startAdditionalCostSelection(card: Card, additional_costs: Array[Dictionary], preselected_cards: Array[CardData] = []) -> Array[CardData]:
	"""Start the selection process for paying additional costs and return selected cards"""
	
	# If pre-selected cards are provided, return them
	if preselected_cards.size() > 0:
		print("🎯 Using pre-selected additional cost cards: ", preselected_cards.map(func(c): return c.cardName))
		return preselected_cards
	
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
			
			# Query GameData for cards in play (MVC pattern)
			var cards_in_play_data = game_data.get_cards_in_play()
			
			# Filter CardData based on requirement
			var valid_card_data: Array[CardData] = []
			for card_data in cards_in_play_data:
				var card_node = card_data.get_card_object()
				if card_node and is_instance_valid(card_node) and _card_matches_requirement(card_node, requirement):
					valid_card_data.append(card_data)
			
			# Start the selection process with CardData
			if valid_card_data.size() > 0:
				var selected_cards = await start_card_selection(requirement, valid_card_data, "sacrifice_for_" + card.cardData.cardName, card)
				return selected_cards
			else:
				print("❌ No valid cards found for selection: ", requirement)
				return []
	
	return []
	
	
func getControllerCards(playerSide = true) -> Array[Card]:
	"""Get all cards the player currently controls (in play)"""
	return GameUtility.getControllerCards(self, playerSide)

func can_card_move(card: Card) -> bool:
	if card.cardData.is_tapped():
		print("⚠️ Cannot move card - already tapped: ", card.cardData.cardName)
		AnimationsManagerAL.show_floating_text(self, card.global_position, "Tapped", Color.ORANGE)
		return false
	return true

func exchange_card_in_spots(from: CombatantFightingSpot, to: CombatantFightingSpot):
	if from.get_parent() != to.get_parent():
		printerr("❌ Cannot exchange cards between different locations")
		return
	var fromCard = from.getCard()
	if fromCard:
		GameUtility.reparentWithoutMoving(fromCard, self)
	if to.getCard() != null:
		from.setCard(to.getCard())
	if fromCard:
		to.setCard(fromCard)

func trigger_phase(phase_name: String):
	"""Trigger all phase-based abilities for a specific phase"""
	match phase_name:
		"BeginningOfTurn":
			await emit_game_event(TriggeredAbility.GameEventType.BEGINNING_OF_TURN, null)
		"EndOfTurn":
			await emit_game_event(TriggeredAbility.GameEventType.END_OF_TURN, null)
			# Note: Cards no longer automatically return from combat at end of turn
		"TurnStarted":
			await emit_game_event(TriggeredAbility.GameEventType.TURN_STARTED, null)

func resolve_queue():
	"""Resolve all resolvables in the queue one by one"""
	if is_resolving_triggers:
		print("⚠️ [RESOLVABLE QUEUE] Already resolving, skipping nested resolution")
		return
	
	if not trigger_queue.has_resolvables():
		return
	
	print("🔄 [RESOLVABLE QUEUE] Starting resolution (", trigger_queue.size(), " resolvables)")
	is_resolving_triggers = true
	
	while trigger_queue.has_resolvables():
		var queued_resolvable = trigger_queue.get_next_resolvable()
		
		if not queued_resolvable:
			break
		
		print("  ⚡ Resolving: ", queued_resolvable.source_card_data.cardName, " - ", queued_resolvable.ability.get_description())
		
		# Execute the resolvable ability with event context
		await AbilityManagerAL.executeAbilityEffect(queued_resolvable.source_card_data, queued_resolvable.ability, self)
	print("✅ [RESOLVABLE QUEUE] Resolution complete")

func emit_game_event(event_type: TriggeredAbility.GameEventType, card_data: CardData = null):
	"""Emit a game event signal - abilities listening to this event will add themselves to the trigger queue"""
	match event_type:
		TriggeredAbility.GameEventType.CARD_ENTERED_PLAY:
			card_entered_play.emit(card_data)
		TriggeredAbility.GameEventType.CARD_DIED:
			card_died.emit(card_data)
		TriggeredAbility.GameEventType.ATTACK_DECLARED:
			attack_declared.emit(card_data)
		TriggeredAbility.GameEventType.DAMAGE_DEALT:
			# Note: damage_dealt has different signature with target and amount
			pass  # This event type should not be emitted through this function
		TriggeredAbility.GameEventType.SPELL_CAST:
			spell_cast.emit(card_data)
		TriggeredAbility.GameEventType.END_OF_TURN:
			end_of_turn.emit(card_data)
		TriggeredAbility.GameEventType.BEGINNING_OF_TURN:
			beginning_of_turn.emit(card_data)
		TriggeredAbility.GameEventType.STRIKE:
			strike.emit(card_data)
	
	# After emitting the event, resolve any resolvables that were added to the queue
	await resolve_queue()

# Note: card_changed_zones is emitted directly in movement handlers, not through emit_game_event
