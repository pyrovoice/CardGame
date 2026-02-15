extends Node3D
class_name Game

const OpponentAIScript = preload("res://Game/scripts/OpponentAI.gd")

# Game event signals for triggered abilities to listen to
signal card_entered_play(card_data: CardData)
signal card_died(card_data: CardData)
signal attack_declared(combat_zone: CombatZone)
signal spell_cast(card_data: CardData)
signal beginning_of_turn(card_data: CardData)
signal end_of_turn(card_data: CardData)
signal card_drawn(cards: Array, is_player: bool)
signal card_changed_zones(card_data: CardData, from_zone: Node, to_zone: Node)
signal strike(card_data: CardData)

# Controller references (MVC: Controller layer)
@onready var player_control: PlayerControl = $GameView/playerControl
@onready var selection_manager: SelectionManager = $GameView/SelectionManager

# Trigger queue for managing triggered abilities
var trigger_queue: ResolvableQueue = ResolvableQueue.new()
var is_resolving_triggers: bool = false  # Track if we're currently resolving the trigger queue

# MVC Architecture
var game_data: GameData  # Model: Single source of truth for game state
@onready var game_view: GameView = $GameView  # View: Manages all visual representations

var doStartGame = true

# Opponent AI system
var opponent_ai: OpponentAI

# Player control system
var playerControlLock:PlayerControlLock = PlayerControlLock.new()
var highlightManager: HighlightManager

# Active hand for PlayerControl
var activeHand: CardHand

# Casting state tracking
var current_casting_card: Card = null
var casting_card_original_parent: Node = null

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

func setActiveHand(hand: CardHand):
	"""Set the active hand that PlayerControl will use"""
	activeHand = hand
	player_control.activeHand = hand

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
	
	# View: Visual representation (loaded from scene)
	game_view.setup()
	
	# Setup UI connections
	game_view.setup_ui_connections(game_data, onTurnStart, func(): game_view.show_admin_console())
	
	# Set zone names for GameData
	game_view.set_zone_names()
	
	# Initialize activeHand to default player_hand
	activeHand = game_view.player_hand
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
	
	highlightManager = HighlightManager.new(self)
	
	for cz in game_view.get_combat_zones():
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
	
	if doStartGame:
		setupGame()
		
func setupGame():
	# Populate decks and draw hands
	populate_decks()
	await drawCard(5, true)
	await drawCard(3, false)
	
	# Debug: Verify MVC state
	print("🎮 [MVC DEBUG] GameData state after setup:")
	game_data.print_game_state()
	
	await onTurnStart(true)
	
func populate_decks():
	# MVC Pattern: Populate both Model (GameData) and View (containers)
	refilLDeck(createCardDatas(game_data.playerDeckList.deck_cards), true, GameZone.e.DECK_PLAYER)
	refilLDeck(createCardDatas(game_data.playerDeckList.deck_cards), true, GameZone.e.DECK_PLAYER)
	refilLDeck(createCardDatas(game_data.playerDeckList.extra_deck_cards), true, GameZone.e.EXTRA_DECK_PLAYER)
	refilLDeck(createCardDatas(game_data.opponentDeckList.deck_cards), false, GameZone.e.DECK_OPPONENT)

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

func execute_move_card(card: Card, destination_zone: GameZone.e, combat_spot: CombatantFightingSpot = null, card_data: CardData = null, origin_zone_enum: GameZone.e = GameZone.e.UNKNOWN) -> bool:
	"""Centralized zone change system - handles all card movements with appropriate animations and triggers (MVC pattern)
	
	Can be called with either:
	- Card object: card parameter
	- CardData directly: card_data + origin_zone_enum parameters
	
	All costs and selections should be paid/made before calling this.
	Events and triggers fire AFTER animations complete.
	
	Args:
		card: The Card object to move (optional if card_data provided)
		destination_zone: Target zone enum (e.g., GameZone.e.GRAVEYARD_PLAYER)
		combat_spot: Optional specific combat spot node (only for combat moves)
		card_data: CardData (optional if card provided)
		origin_zone_enum: Source zone (optional if card provided)
	
	Returns:
		bool: True if move was successful, false otherwise
	"""
	# Get card_data and origin from either Card object or parameters
	if card:
		card_data = card.cardData
		var origin_zone = card.get_parent()
		origin_zone_enum = _get_zone_enum(origin_zone)
	elif not card_data:
		push_error("execute_move_card: must provide either card or card_data")
		return false
	
	var origin_zone_node: Node = card.get_parent() if card else game_view.get_zone_container(origin_zone_enum)
	
	print("📦 Moving ", card_data.cardName, " from ", GameZone.e.keys()[origin_zone_enum], " to ", GameZone.e.keys()[destination_zone])
	
	# MVC Pattern: Update Model first, then animate View
	# Combat zones handled separately via card_to_combat_spot
	if destination_zone != GameZone.e.COMBAT_PLAYER and destination_zone != GameZone.e.COMBAT_OPPONENT:
		game_data.move_card(card_data, destination_zone)
	else:
		# Combat: Store spot assignment in GameData
		if combat_spot:
			game_data.assign_card_to_combat_spot(card_data, combat_spot)
	
	# Route to specific movement handlers for animations and triggers
	match [origin_zone_enum, destination_zone]:
		[GameZone.e.DECK_PLAYER, GameZone.e.HAND_PLAYER], [GameZone.e.DECK_OPPONENT, GameZone.e.HAND_OPPONENT]:
			await _move_deck_to_hand(card_data, destination_zone)
		[_, GameZone.e.BATTLEFIELD_PLAYER], [_, GameZone.e.BATTLEFIELD_OPPONENT]:
			await _move_to_battlefield(card_data, destination_zone)
		[_, GameZone.e.GRAVEYARD_PLAYER], [_, GameZone.e.GRAVEYARD_OPPONENT]:
			await _move_to_graveyard(card_data, destination_zone, origin_zone_enum)
		[GameZone.e.BATTLEFIELD_PLAYER, GameZone.e.COMBAT_PLAYER], [GameZone.e.BATTLEFIELD_OPPONENT, GameZone.e.COMBAT_OPPONENT]:
			await _move_base_to_combat(card_data, combat_spot, origin_zone_node)
		[GameZone.e.COMBAT_PLAYER, GameZone.e.BATTLEFIELD_PLAYER], [GameZone.e.COMBAT_OPPONENT, GameZone.e.BATTLEFIELD_OPPONENT]:
			await _move_combat_to_base(card_data, destination_zone, origin_zone_node)
		_:
			await _move_generic(card_data, destination_zone, origin_zone_enum, origin_zone_node)
	
	print("✅ Move complete: ", card_data.cardName)
	return true

func _get_zone_type(container: Node) -> String:
	"""Determine the type of a zone container for routing (legacy string-based)"""
	if container is CardContainer:
		if container == game_view.deck or container == game_view.deck_opponent:
			return "Deck"
		elif container == game_view.graveyard:
			return "Player's Graveyard"
		elif container == game_view.graveyard_opponent:
			return "Opponent's Graveyard"
		elif container == game_view.extra_deck:
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
	if container == game_view.player_hand:
		return GameZone.e.HAND_PLAYER
	elif container == game_view.opponent_hand:
		return GameZone.e.HAND_OPPONENT
	elif container == game_view.get_player_base():
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

func _move_deck_to_hand(card_data: CardData, dest_zone: GameZone.e):
	"""Handle deck to hand movement - draw animation + trigger (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	
	# View: Animate deck to hand
	await game_view.animate_deck_to_hand(card_data, dest_zone)
	
	# Trigger card_drawn event
	card_drawn.emit([card_data], card_data.playerControlled)

func _move_to_battlefield(card_data: CardData, dest_zone: GameZone.e):
	"""Handle any zone to battlefield - entering play (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	
	# View: Animate to battlefield (GameView handles card creation, parenting, and positioning)
	await game_view.animate_card_to_battlefield(card_data, dest_zone)
	
	# Trigger card entered play
	await emit_game_event(TriggeredAbility.GameEventType.CARD_ENTERED_PLAY, card_data)
	
	# Apply static and replacement abilities
	for ability in card_data.static_abilities:
		ability.apply_to_game(self)
	for ability in card_data.replacement_abilities:
		ability.apply_to_game(self)

func _move_to_graveyard(card_data: CardData, dest_zone: GameZone.e, origin_zone_enum: GameZone.e):
	"""Handle battlefield/anywhere to graveyard - death (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	
	# View: Animate to graveyard
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_to_graveyard: Could not find graveyard container")
		return
	
	await game_view.animate_card_to_graveyard(card_data, dest.global_position)
	
	# Remove battlefield abilities if leaving battlefield
	var from_battlefield = (origin_zone_enum == GameZone.e.BATTLEFIELD_PLAYER or origin_zone_enum == GameZone.e.BATTLEFIELD_OPPONENT or 
						   origin_zone_enum == GameZone.e.COMBAT_PLAYER or origin_zone_enum == GameZone.e.COMBAT_OPPONENT)
	
	if from_battlefield:
		for ability in card_data.triggered_abilities:
			ability.unregister_from_game(self)
		for ability in card_data.static_abilities:
			ability.remove_from_game(self)
		for ability in card_data.replacement_abilities:
			ability.remove_from_game(self)
		
		# Trigger card died
		emit_game_event(TriggeredAbility.GameEventType.CARD_DIED, card_data)
	
	# Unsubscribe from game signals
	card_data.unsubscribe_from_game_signals(self)
	
	# Clean up Card view
	game_view.destroy_card_view(card_data)

func _move_base_to_combat(card_data: CardData, combat_spot: CombatantFightingSpot, origin_zone_node: Node):
	"""Handle PlayerBase to Combat - attack movement (MVC pattern)"""
	if not combat_spot:
		push_error("_move_base_to_combat: combat_spot is required")
		return
	
	# View: Animate to combat
	game_view.animate_card_to_combat(card_data, combat_spot)
	
	card_changed_zones.emit(card_data, origin_zone_node, combat_spot)

func _move_combat_to_base(card_data: CardData, dest_zone: GameZone.e, origin_zone_node: Node):
	"""Handle Combat to PlayerBase - retreat movement"""
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_combat_to_base: Could not find battlefield container")
		return
	
	var target_position = game_view.get_next_battlefield_location()
	if target_position == Vector3.INF:
		return
	
	# View: Animate back to base
	await game_view.animate_card_to_base(card_data, target_position, dest)
	
	card_changed_zones.emit(card_data, origin_zone_node, dest)

func _move_generic(card_data: CardData, dest_zone: GameZone.e, origin_zone_enum: GameZone.e, origin_zone_node: Node):
	"""Handle any other zone transitions with generic animation (MVC pattern)"""
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_generic: Could not find destination container")
		return
	
	# View: Animate card move
	await game_view.animate_card_move(card_data, dest.global_position)
	
	if dest is CardContainer:
		pass
	elif dest is CardHand:
		var card = card_data.get_card_object()
		if card:
			GameUtility.reparentCardWithoutMovingRepresentation(card, dest)
			dest.arrange_cards_fan([card])
		elif dest is CombatantFightingSpot:
			game_view.animate_card_to_combat(card_data, dest)
		else:
			push_error("_move_generic: Unsupported destination type")
			return
	
	var from_battlefield = (origin_zone_enum == GameZone.e.BATTLEFIELD_PLAYER or origin_zone_enum == GameZone.e.BATTLEFIELD_OPPONENT or 
						   origin_zone_enum == GameZone.e.COMBAT_PLAYER or origin_zone_enum == GameZone.e.COMBAT_OPPONENT)
	
	if from_battlefield:
		for ability in card_data.static_abilities:
			ability.remove_from_game(self)
		for ability in card_data.replacement_abilities:
			ability.remove_from_game(self)
	
	var dest_node = game_view.get_zone_container(dest_zone)
	card_changed_zones.emit(card_data, origin_zone_node, dest_node)

func tryMoveCard(card_data: CardData, target_location: Node3D) -> void:
	"""Attempt to move a card to the specified location - handles user-initiated movement based on source zone
	
	This method is for USER INPUT (drag/drop, clicks). For programmatic card movement from effects,
	use execute_move_card() instead.
	"""
	if not card_data:
		return
	
	# Default to PlayerBase if no target specified
	if not target_location:
		target_location = game_view.get_player_base()
	
	var source_zone = card_data.current_zone
	
	match source_zone:
		GameZone.e.HAND_PLAYER, GameZone.e.EXTRA_DECK_PLAYER:
			# Playing from hand - use the full play logic
			# Get Card view for play logic
			var card = card_data.get_card_object()
			if card:
				tryPlayCard(card, target_location)
		
		GameZone.e.BATTLEFIELD_PLAYER:
			await _try_move_from_battlefield(card_data, target_location)
		
		GameZone.e.COMBAT_PLAYER:
			await _try_move_from_combat(card_data, target_location)

func _try_move_from_battlefield(card_data: CardData, target_location: Node3D) -> void:
	"""Handle user-initiated movement from battlefield to combat"""
	if not target_location is CombatantFightingSpot:
		return
	
	var combat_spot = target_location as CombatantFightingSpot
	
	# Find empty slot if target is occupied
	if combat_spot.getCard():
		combat_spot = (combat_spot.get_parent() as CombatZone).getFirstEmptyLocation(card_data.playerControlled)
	
	if combat_spot == null:
		print("No empty slot found for " + card_data.cardName)
		return
	
	# Check if card can move (not tapped)
	if not can_card_move(card_data):
		return
	
	# Tap the card for movement and mark as attacked
	card_data.tap()
	card_data.hasAttackedThisTurn = true
	
	var card = card_data.get_card_object()
	
	# Move using centralized system
	await execute_move_card(card, GameZone.e.COMBAT_PLAYER, combat_spot, card_data, card_data.current_zone)

func _try_move_from_combat(card_data: CardData, target_location: Node3D) -> void:
	"""Handle user-initiated movement from combat zone (retreat or swap)"""
	if target_location is PlayerBase:
		# Retreat from combat to base
		if can_card_move(card_data):
			# Tap card for movement
			card_data.tap()
			
			var card = card_data.get_card_object()
			
			# Move using centralized system
			await execute_move_card(card, GameZone.e.BATTLEFIELD_PLAYER, null, card_data, card_data.current_zone)
	elif target_location is CombatantFightingSpot:
		# Swapping positions within the same combat zone
		var card = card_data.get_card_object()
		if card and card.get_parent() is CombatantFightingSpot and \
		card.get_parent().get_parent() == target_location.get_parent():
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
	if source_zone == GameZone.e.HAND_PLAYER or source_zone == GameZone.e.EXTRA_DECK_PLAYER:
		if card.cardData.playerControlled:
			if source_zone == GameZone.e.HAND_PLAYER:
				correct_hand = game_view.player_hand
			elif source_zone == GameZone.e.EXTRA_DECK_PLAYER:
				correct_hand = game_view.extra_hand
		else:
			correct_hand = game_view.opponent_hand
	current_casting_card = card
	casting_card_original_parent = correct_hand
	
	# Animate casting preparation (only for cards from hand/extra deck)
	if source_zone == GameZone.e.HAND_PLAYER or source_zone == GameZone.e.EXTRA_DECK_PLAYER:
		GameUtility.reparentCardWithoutMovingRepresentation(card, self)
		
		# Move card to cast preparation position
		await game_view.animate_casting_preparation(card, card.is_facedown)
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
	# Can play cards from hand or extra deck (use specific player zones)
	var can_play_from_zone = (source_zone == GameZone.e.HAND_PLAYER) or (source_zone == GameZone.e.EXTRA_DECK_PLAYER)
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
		var dest_zone = GameZone.e.BATTLEFIELD_PLAYER if card.cardData.playerControlled else GameZone.e.BATTLEFIELD_OPPONENT
		await execute_move_card(card, dest_zone)
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
	game_view.show_floating_text(target.global_position, "-" + str(damage_amount), Color.RED, self)
	
	# Resolve state-based actions after damage
	await resolveStateBasedAction()

	
	# Emit attack_declared signal for triggered abilities
	attack_declared.emit(card.cardData)
	
	# Resolve state-based actions after attack
	await resolveStateBasedAction()

func drawCard(howMany: int = 1, player = true):
	# MVC Pattern: Update Model → Update Views → Trigger Events
	
	var _deck = game_view.deck if player else game_view.deck_opponent
	var zone_name = GameZone.e.HAND_PLAYER if player else GameZone.e.HAND_OPPONENT
	
	# Store deck position for animations
	var deck_position = _deck.global_position
	
	# Model: Get top N cards from GameData deck zone
	var deck_cards = game_data.cards_in_deck_player if player else game_data.cards_in_deck_opponent
	var cards_to_draw = deck_cards.slice(0, min(howMany, deck_cards.size()))
	
	if cards_to_draw.is_empty():
		print("⚠️ No cards to draw from deck")
		return
	
	# Model: Move cards to hand zone
	for card_data in cards_to_draw:
		game_data.move_card(card_data, zone_name)
	
	# View: Create and animate card views
	var card_views = await game_view.create_and_animate_drawn_cards(cards_to_draw, player, deck_position, createCardFromData)
	
	# Emit card_drawn signal for triggered abilities
	card_drawn.emit(card_views, player)
	await resolveStateBasedAction()

func resolveCombats():
	var lock = playerControlLock.addLock()
	for cv in game_view.get_combat_zones():
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
	for child in game_view.player_hand.get_children():
		if child is Card:
			all_cards.append(child)
	
	# Cards in player base
	for child in game_view.get_player_base().get_children():
		if child is Card:
			all_cards.append(child)
	
	# Cards in combat zones
	for zone in game_view.get_combat_zones():
		for spot in zone.allySpots:
			var card = spot.getCard()
			if card is Card:
				all_cards.append(card)
	
	return all_cards

func _get_target_zone(target_location: Node3D) -> GameZone.e:
	# Note: This function may need player/opponent context to return the correct specific zone
	if target_location is CombatantFightingSpot:
		return GameZone.e.COMBAT_PLAYER  # TODO: distinguish player/opponent
	elif target_location is PlayerBase:
		return GameZone.e.BATTLEFIELD_PLAYER  # TODO: distinguish player/opponent
	elif target_location == game_view.player_hand:
		return GameZone.e.HAND_PLAYER
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
			game_view.animate_combat_strike(player_card, opponent_card)
			
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
	for combat_location_data in game_data.combatLocationDatas:
		if combat_location_data.opponent_capture_current.value >= combat_location_data.opponent_capture_threshold.value:
			_handle_location_captured(combat_location_data.relatedLocation, false)
		elif combat_location_data.player_capture_current.value >= combat_location_data.player_capture_threshold.value:
			_handle_location_captured(combat_location_data.relatedLocation, true)

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
	if game_data.cards_in_deck_player.size() <= game_data.playerDeckList.deck_cards.size():
		refilLDeck(createCardDatas(game_data.playerDeckList.deck_cards), true, GameZone.e.DECK_PLAYER)
	
	if game_data.cards_in_deck_opponent.size() <= game_data.opponentDeckList.deck_cards.size():
		refilLDeck(createCardDatas(game_data.opponentDeckList.deck_cards), false, GameZone.e.DECK_OPPONENT)

func refilLDeck(cards: Array[CardData], isPlayerOwned: bool, zone_name: GameZone.e):
	for c:CardData in cards:
		c.playerOwned = isPlayerOwned
	
	cards.shuffle()
	
	# Add to GameData model (handles zone array and tracking)
	for c in cards:
		game_data.add_card_to_zone(c, zone_name)
	
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
	game_data.add_card_to_zone(card_data, zone)
	
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

func getCardZone(card: Card) -> GameZone.e:
	"""Legacy method - prefer using game_data.get_card_zone(card_data) for MVC compliance"""
	if card and card.cardData:
		return game_data.get_card_zone(card.cardData)
	return GameZone.e.UNKNOWN

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
	return game_view.get_graveyard(true)

func get_opponent_graveyard() -> Graveyard:
	"""Get the opponent's graveyard"""
	return game_view.get_graveyard(false)

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
	
	for card_data: CardData in game_data.cards_in_extra_deck_player:
		if CardPaymentManagerAL.isCardDataCastable(card_data):
			has_castable_cards = true
			break
	
	game_view.update_extra_deck_outline(has_castable_cards)


func _toggleExtraDeckView():
	var extra_hand_shown = game_view.toggle_extra_deck_view()
	if extra_hand_shown:
		setActiveHand(game_view.extra_hand)
		# Get castable cards for display
		var castable_cards: Array[CardData] = []
		for card_data: CardData in game_data.cards_in_extra_deck_player:
			if CardPaymentManagerAL.isCardDataCastable(card_data):
				castable_cards.append(card_data)
		# View handles arrangement and headless check
		await game_view.arrange_extra_deck_hand(castable_cards, createCardFromData)
	else:
		setActiveHand(game_view.player_hand)

func _restore_cancelled_card():
	"""Restore casting card to its original location and clean up casting state"""
	if current_casting_card and casting_card_original_parent:
		# Reset visual properties before reparenting
		game_view.restore_cancelled_card(current_casting_card, casting_card_original_parent)
	
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
	elif objectUnderMouse == game_view.extra_deck:
		_toggleExtraDeckView()

func showCardPopup(card: Card):
	"""Show popup for a card"""
	
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

func can_card_move(card_data: CardData) -> bool:
	if card_data.is_tapped():
		print("⚠️ Cannot move card - already tapped: ", card_data.cardName)
		# Show visual feedback if card view exists
		var card = card_data.get_card_object()
		if card:
			game_view.show_floating_text(card.global_position, "Tapped", Color.ORANGE, self)
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
