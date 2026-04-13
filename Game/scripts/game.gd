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
signal end_of_turn_cleanup()  # Fires after end_of_turn for cleanup (remove temporary effects, orphaned abilities)
signal card_drawn(cards: Array, is_player: bool)
signal card_changed_zones(card_data: CardData, from_zone: GameZone.e, to_zone: GameZone.e)
signal strike(card_data: CardData)
signal card_recycled(card_data: CardData)

# Controller references (MVC: Controller layer)
@onready var player_control: PlayerControl = $GameView/playerControl
@onready var selection_manager: SelectionManager = $GameView/SelectionManager

# Trigger queue for managing triggered abilities
var trigger_queue: ResolvableQueue = ResolvableQueue.new()
var is_resolving_triggers: bool = false  # Track if we're currently resolving the trigger queue

# Orphaned abilities - triggered abilities not attached to any card (e.g., delayed effects)
# These persist independently and clean up after resolution
var orphaned_abilities: Array[TriggeredAbility] = []

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

func createCardDatas(card_data_templates: Array[CardData], destination_zone: GameZone.e, player_owned: bool) -> Array[CardData]:
	var new_cards: Array[CardData] = []
	for c in card_data_templates:
		var new_card_data = createCardData(c, destination_zone, player_owned)
		if new_card_data != null:
			new_cards.push_back(new_card_data)
	return new_cards
	
func createCardData(card_data_template: CardData, destination_zone: GameZone.e, player_owned: bool) -> CardData:
	"""Create a new CardData by duplicating a template and registering its abilities to game signals"""
	if destination_zone == GameZone.e.UNKNOWN:
		push_error("createCardData: destination_zone cannot be UNKNOWN")
		return null
	var new_card_data = CardLoaderAL.duplicateCardScript(card_data_template)
	new_card_data.playerOwned = player_owned
	new_card_data.playerControlled = player_owned
	
	# Add to zone first
	game_data.add_card_to_zone(new_card_data, destination_zone)
	
	# Create view
	game_view.create_card_view(new_card_data, destination_zone)
	
	# Subscribe to game signals (registers triggered abilities, applies static/replacement abilities)
	# For battlefield zones, this will properly register all abilities
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
		game_data.playerDeckList.deck_cards = DeckConfigAL.player_deck_cards.duplicate()
		game_data.playerDeckList.extra_deck_cards = DeckConfigAL.player_extra_deck_cards.duplicate()
		game_data.opponentDeckList.deck_cards = DeckConfigAL.opponent_deck_cards.duplicate()
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
	replenish_deck_zone(GameZone.e.DECK_PLAYER, 2)
	replenish_deck_zone(GameZone.e.EXTRA_DECK_PLAYER)
	replenish_deck_zone(GameZone.e.DECK_OPPONENT)

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
		await drawCard(3)
	@warning_ignore("integer_division")
	await drawCard(game_data.danger_level.getValue()/3, false)
	game_data.setOpponentGold()
	await opponent_ai.execute_main_phase()

func execute_move_card(cardData: CardData, destination_zone: GameZone.e, origin_zone_enum: GameZone.e = GameZone.e.UNKNOWN, index: int = -1) -> bool:
	"""Centralized zone change system - handles all card movements with appropriate animations and triggers (MVC pattern)
	
	All costs and selections should be paid/made before calling this.
	Events and triggers fire AFTER animations complete.
	
	For combat zones, the card's position is determined by its index in the combat zone array.
	
	Args:
		cardData: The CardData to move
		destination_zone: Target zone enum (e.g., GameZone.e.GRAVEYARD_PLAYER)
		origin_zone_enum: Source zone (if UNKNOWN, will be queried from game_data)
		index: Optional array index for positioning in destination zone (-1 = end of array)
	
	Returns:
		bool: True if move was successful, false otherwise
	"""
	# Validate cardData is provided
	if not cardData:
		push_error("execute_move_card: cardData is required")
		return false
	
	# Get origin zone - either from parameter or query game_data
	var origin_zone = origin_zone_enum
	if origin_zone == GameZone.e.UNKNOWN:
		origin_zone = game_data.get_card_zone(cardData)
	
	# MVC Pattern: Update Model first (add to zone array), then animate View
	game_data.move_card(cardData, destination_zone, index)
	
	# Get origin zone node for signal emissions
	var origin_zone_node = game_view.get_zone_container(origin_zone)
	
	# Route to specific movement handlers for animations and triggers
	# Check for specific zone transition patterns
	if (origin_zone == GameZone.e.DECK_PLAYER and destination_zone == GameZone.e.HAND_PLAYER) or \
	   (origin_zone == GameZone.e.DECK_OPPONENT and destination_zone == GameZone.e.HAND_OPPONENT):
		await _move_deck_to_hand(cardData, destination_zone)
	elif GameZone.is_battlefield_zone(destination_zone):
		await _move_to_battlefield(cardData, destination_zone)
	elif destination_zone == GameZone.e.GRAVEYARD_PLAYER or destination_zone == GameZone.e.GRAVEYARD_OPPONENT:
		await _move_to_graveyard(cardData, destination_zone, origin_zone_enum)
	elif GameZone.is_battlefield_zone(origin_zone) and GameZone.is_combat_zone(destination_zone):
		await _move_base_to_combat(cardData, destination_zone, index)
	elif GameZone.is_combat_zone(origin_zone) and GameZone.is_battlefield_zone(destination_zone):
		await _move_combat_to_base(cardData, destination_zone, origin_zone_node)
	else:
		await _move_generic(cardData, destination_zone, origin_zone_enum, origin_zone_node)
	
	return true


func check_effect_condition(condition: String, source_card_data: CardData) -> bool:
	"""Check if an effect condition is met (Controller method)
	
	Args:
		condition: Condition string (e.g., "IfAlive", "IfTapped")
		source_card_data: The card executing the effect
	
	Returns:
		bool: True if condition is met, false otherwise
	"""
	match condition:
		"IfAlive":
			# Check if source card is in play using GameData (Model) - headless-safe
			var source_zone = game_data.get_card_zone(source_card_data)
			if not GameZone.is_in_play(source_zone):
				print("⚠️ ", source_card_data.cardName, " is not alive (zone: ", GameZone.e.keys()[source_zone], "), condition not met")
				return false
			return true
		"":
			# No condition - always passes
			return true
		_:
			push_warning("Unknown effect condition: ", condition)
			return true  # Unknown conditions default to passing

func recycle_card(card_data: CardData) -> bool:
	"""Recycle a card from hand - removes it from game, grants gold, triggers event (Controller method)
	
	Args:
		card_data: The card to recycle (must be in player's hand)
	
	Returns:
		bool: True if card was successfully recycled, false otherwise
	"""
	if not card_data:
		push_error("recycle_card: card_data is null")
		return false
	
	# Validation: Check if card is in player's hand
	var card_zone = game_data.get_card_zone(card_data)
	if card_zone != GameZone.e.HAND_PLAYER:
		print("⚠️ Cannot recycle card - not in player's hand (current zone: ", GameZone.e.keys()[card_zone], ")")
		return false
	
	# Validation: Check if player has recycling uses remaining
	if game_data.recycling_remaining.value <= 0:
		print("⚠️ Cannot recycle card - no recycling uses remaining this turn")
		return false
	
	print("♻️ Recycling card: ", card_data.cardName)
	
	# MVC Pattern: Update Model → Update View → Trigger Events
	
	# Model: Remove card from GameData
	var destroyed = game_data.destroy_card(card_data)
	if not destroyed:
		push_error("recycle_card: Failed to destroy card in GameData")
		return false
	
	# Model: Decrease recycling count
	game_data.recycling_remaining.value -= 1
	
	# Model: Add gold to player
	game_data.add_gold(1)
	
	# View: Handle visual feedback and cleanup
	game_view.recycle_card_view(card_data)
	
	# Unsubscribe from game signals
	card_data.unsubscribe_from_game_signals(self)
	
	# Event: Trigger card_recycled event
	await emit_game_event(TriggeredAbility.GameEventType.CARD_RECYCLED, card_data)
	
	print("✅ Card recycled successfully. Recycling remaining: ", game_data.recycling_remaining.value, "/3")
	return true


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

func _move_to_graveyard(card_data: CardData, dest_zone: GameZone.e, origin_zone: GameZone.e):
	"""Handle battlefield/anywhere to graveyard - death (MVC pattern)"""
	# Note: GameData already updated by execute_move_card
	
	# View: Animate to graveyard
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_to_graveyard: Could not find graveyard container")
		return
	
	await game_view.animate_card_to_graveyard(card_data, dest_zone)
	
	# Remove battlefield abilities if leaving battlefield
	var from_battlefield = GameZone.is_in_play(origin_zone)
	
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

func _move_base_to_combat(card_data: CardData, destination_zone: GameZone.e, targetPosition: int):
	"""Handle PlayerBase to Combat - attack movement (MVC pattern)
	
	Args:
		card_data: The card to move
		destination_zone: The combat zone enum the card is moving to
		targetPosition: The index position in the combat zone array
	
	The card has already been added to the zone array by execute_move_card.
	"""
	
	# View: Animate to combat (await the animation)
	await game_view.animate_card_to_combat(card_data, destination_zone, targetPosition)
	
	# Emit zone change signal
	var origin_zone = GameZone.e.BATTLEFIELD_PLAYER if card_data.playerControlled else GameZone.e.BATTLEFIELD_OPPONENT
	card_changed_zones.emit(card_data, origin_zone, destination_zone)

func _move_combat_to_base(card_data: CardData, dest_zone: GameZone.e, origin_zone_node: Node):
	"""Handle Combat to PlayerBase - retreat movement"""
	var dest = game_view.get_zone_container(dest_zone)
	if not dest:
		push_error("_move_combat_to_base: Could not find battlefield container")
		return
	
	# View: Animate back to base
	await game_view.animate_card_to_base(card_data, dest_zone)
	
	card_changed_zones.emit(card_data, origin_zone_node, dest)

func _move_generic(card_data: CardData, dest_zone: GameZone.e, origin_zone: GameZone.e, origin_zone_node: Node):
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
	else:
		push_error("_move_generic: Unsupported destination type: " + str(dest.get_class()))
		return
	
	var from_battlefield = GameZone.is_in_play(origin_zone)
	
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
	
	var source_zone = game_data.get_card_zone(card_data)
	
	# Convert target location to zone enum
	var dest_zone: GameZone.e
	if target_location:
		dest_zone = _get_target_zone(target_location)
	else:
		# Default to PlayerBase if no target specified
		dest_zone = GameZone.e.BATTLEFIELD_PLAYER
	
	# Handle movement based on source zone
	match source_zone:
		GameZone.e.HAND_PLAYER, GameZone.e.EXTRA_DECK_PLAYER:
			# Check for recycling - only allow when viewing player_hand (not extra_deck view)
			if dest_zone == GameZone.e.RECYCLE_ZONE:
				if activeHand != game_view.player_hand:
					print("⚠️ Cannot recycle from extra deck view")
					return
				# Recycling is not a zone movement - call recycle_card directly
				await recycle_card(card_data)
				return
			
			# Playing from hand/extra deck
			if dest_zone == GameZone.e.UNKNOWN:
				# Default to battlefield if target is not recognized
				dest_zone = GameZone.e.BATTLEFIELD_PLAYER
			
			# Try to play the card to the destination zone
			tryPlayCard(card_data, dest_zone)
		
		GameZone.e.BATTLEFIELD_PLAYER:
			await _try_move_from_battlefield(card_data, target_location)
		
		GameZone.e.COMBAT_PLAYER_1, GameZone.e.COMBAT_PLAYER_2, GameZone.e.COMBAT_PLAYER_3:
			await _try_move_from_combat(card_data, target_location)

func _try_move_from_battlefield(card_data: CardData, target_location: Node3D) -> void:
	"""Handle user-initiated movement from battlefield to combat"""
	if not target_location is CombatZone:
		return
	
	var combat_zone = target_location as CombatZone
	
	# Check if card can move (not tapped)
	if not can_card_move(card_data):
		return
	
	# Tap the card for movement and mark as attacked
	card_data.tap()
	card_data.hasAttackedThisTurn = true
	
	# Determine which combat zone based on card's controller
	var zone_index = game_view.get_combat_zones().find(combat_zone)
	var dest_zone: GameZone.e
	if card_data.playerControlled:
		dest_zone = (GameZone.e.COMBAT_PLAYER_1 + zone_index) as GameZone.e
	else:
		dest_zone = (GameZone.e.COMBAT_OPPONENT_1 + zone_index) as GameZone.e
	
	# Move using centralized system
	await execute_move_card(card_data, dest_zone)

func _try_move_from_combat(card_data: CardData, target_location: Node3D) -> void:
	"""Handle user-initiated movement from combat zone (retreat)"""
	if target_location is PlayerBase:
		# Retreat from combat to base
		if can_card_move(card_data):
			# Tap card for movement
			card_data.tap()
			
			# Move using centralized system
			await execute_move_card(card_data, GameZone.e.BATTLEFIELD_PLAYER)
	else:
		print("❌ Cannot move card from combat to that location")

func _canPlayCard(source_zone: GameZone.e) -> bool:
	"""Check if cards can be played from this zone"""
	return source_zone in [GameZone.e.HAND_PLAYER, GameZone.e.HAND_OPPONENT, GameZone.e.EXTRA_DECK_PLAYER]

func tryPlayCard(card_data: CardData, destination_zone: GameZone.e = GameZone.e.UNKNOWN, pre_selections: SelectionManager.CardPlaySelections = null, pay_cost = true) -> void:
	"""Play a card from hand/extra deck to battlefield or combat
	
	Args:
		card_data: The card to play
		destination_zone: Target zone (defaults to appropriate battlefield zone)
		pre_selections: Pre-made selections for costs and targets
		pay_cost: Whether to pay costs (false for effect-based casting)
	"""
	if not card_data:
		print("❌ [TRYPLAYCARD] CardData is null")
		return
	print("🎮 [TRYPLAYCARD] Attempting to play: ", card_data.cardName)
	var source_zone = game_data.get_card_zone(card_data)
	print("🎮 [TRYPLAYCARD] Source zone: ", GameZone.e.keys()[source_zone] + ", Dest: ", GameZone.e.keys()[destination_zone])
	
	# Validate source zone
	if not _canPlayCard(source_zone):
		print("❌ [TRYPLAYCARD] Cannot play from this zone")
		return
	
	# Determine destination zone if not specified
	if destination_zone == GameZone.e.UNKNOWN:
		destination_zone = GameZone.e.BATTLEFIELD_PLAYER if card_data.playerControlled else GameZone.e.BATTLEFIELD_OPPONENT
	
	print("✅ [TRYPLAYCARD] Passed initial checks, proceeding with card play")
	
	# Use CardPlaySelections directly
	# If pre_selections is provided (even empty), skip interactive selection entirely
	var selection_data: SelectionManager.CardPlaySelections
	if pre_selections != null:
		print("🎯 Using pre-specified selections for card play")
		selection_data = pre_selections
	else:
		selection_data = null

	# Get Card view object for animations (only if needed)
	var card: Card = null
	var correct_hand = null
	if source_zone == GameZone.e.HAND_PLAYER or source_zone == GameZone.e.HAND_OPPONENT or source_zone == GameZone.e.EXTRA_DECK_PLAYER:
		# Get Card view for animation (only required in non-headless mode)
		card = card_data.get_card_object()
		
		# In headless mode or when Card view doesn't exist, skip animations
		if card and not game_view.headless:
			if card_data.playerControlled:
				if source_zone == GameZone.e.HAND_PLAYER:
					correct_hand = game_view.player_hand
				elif source_zone == GameZone.e.EXTRA_DECK_PLAYER:
					correct_hand = game_view.extra_hand
			else:
				correct_hand = game_view.opponent_hand
			
			current_casting_card = card
			casting_card_original_parent = correct_hand
			
			# Animate casting preparation
			GameUtility.reparentCardWithoutMovingRepresentation(card, self)
			await game_view.animate_casting_preparation(card, card.cardData.is_facedown)
			if !card_data.playerControlled:
				await get_tree().create_timer(0.5).timeout
		elif not game_view.headless and not card:
			# Non-headless mode but no Card view - this is an error
			print("❌ [TRYPLAYCARD] Card view not found for animation (required in non-headless mode)")
			return
	
	# Collect all required player selections upfront (including casting choice)
	if selection_data == null:
		print("🎮 [TRYPLAYCARD] Calling _collectAllPlayerSelections for ", card_data.cardName)
		selection_data = await _collectAllPlayerSelections(card_data)
	else:
		print("🎯 Skipping selection collection - using pre-specified selections")
	
	# If any selection was cancelled, abort the play
	if selection_data.cancelled:
		_restore_cancelled_card()
		return
	
	# Execute the card play with all collected selections
	await tryPayAndSelectsForCardPlay(card_data, selection_data, pay_cost)
	
	# If playing directly to combat, handle combat entry
	if GameZone.is_combat_zone(destination_zone):
		await execute_move_card(card_data, destination_zone)

func _executeCardPlay(cardData: CardData, spell_targets: Array[CardData]):
	# Handle spells differently - they cast their effects then go to graveyard
	if cardData.hasType(CardData.CardType.SPELL):
		await _executeSpellWithTargets(cardData, spell_targets)
		# Move spell to graveyard after effects resolve using centralized movement system
		var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if cardData.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
		await execute_move_card(cardData, graveyard_zone)
	else:
		# Non-spell cards enter the battlefield normally
		var dest_zone = GameZone.e.BATTLEFIELD_PLAYER if cardData.playerControlled else GameZone.e.BATTLEFIELD_OPPONENT
		await execute_move_card(cardData, dest_zone)
	await resolveStateBasedAction()

func _executeSpellWithTargets(cardData: CardData, targets: Array[CardData]):
	if not cardData.hasType(CardData.CardType.SPELL):
		print("❌ Tried to execute spell effects on non-spell card: ", cardData.cardName)
		return
	
	print("✨ Casting spell: ", cardData.cardName)
	
	# Get spell abilities from the card
	var spell_abilities = cardData.spell_abilities
	
	if spell_abilities.is_empty():
		print("⚠️ Spell has no effects to execute: ", cardData.cardName)
		return
	
	# Execute each spell effect with targets
	var target_index = 0
	for spell_ability in spell_abilities:
		var effect_targets = []
		
		# Assign targets to effects that need them
		if spell_ability.requires_target() and target_index < targets.size():
			effect_targets = [targets[target_index]]
			target_index += 1
		
		await _executeSpellEffectWithTargets(cardData, spell_ability, effect_targets)
	
	print("✨ Finished casting spell: ", cardData.cardName)

func _executeSpellEffectWithTargets(cardData: CardData, spell_ability: SpellAbility, targets: Array):
	# For targeting effects, add targets to parameters
	if targets.size() > 0:
		spell_ability.effect_parameters["Targets"] = targets
	
	# Use the unified ability execution system (pass CardData instead of Card)
	await AbilityManagerAL.executeAbilityEffect(cardData, spell_ability, self)

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
	var deck_zone = GameZone.e.DECK_PLAYER if player else GameZone.e.DECK_OPPONENT
	var deck_cards = game_data.get_cards_in_zone(deck_zone)
	var cards_to_draw = deck_cards.slice(0, min(howMany, deck_cards.size()))
	
	if cards_to_draw.is_empty():
		print("⚠️ No cards to draw from deck")
		return
	
	# Model: Move cards to hand zone
	for card_data in cards_to_draw:
		game_data.move_card(card_data, zone_name)
	
	# View: Create and animate card views
	var card_views = await game_view.create_and_animate_drawn_cards(cards_to_draw, player, deck_position, game_view.create_card_view)
	
	# Emit CARD_DRAWN game event for all drawn cards
	await emit_game_event(TriggeredAbility.GameEventType.CARD_DRAWN, cards_to_draw)
	
	await resolveStateBasedAction()

func resolveCombats():
	var lock = playerControlLock.addLock()
	for i in range(game_view.get_combat_zones().size()):
		var combat_zone_enum := (GameZone.e.COMBAT_PLAYER_1 + i) as GameZone.e
		await resolveCombatInZone(combat_zone_enum)
	playerControlLock.removeLock(lock)

func resolve_unresolved_combats():
	var lock = playerControlLock.addLock()
	for cld in game_data.combatLocationDatas:
		if !cld.isCombatResolved.value:
			# Convert CombatZone to GameZone.e
			var zone_index = game_view.get_combat_zones().find(cld.relatedLocation)
			if zone_index >= 0:
				var combat_zone_enum := (GameZone.e.COMBAT_PLAYER_1 + zone_index) as GameZone.e
				await resolve_combat_for_zone(combat_zone_enum)
	
	playerControlLock.removeLock(lock)

func resolve_combat_for_zone(combat_zone_enum: GameZone.e):
	
	# Convert to player zone to get the view object (combat zones share the same physical location)
	var player_zone_enum = combat_zone_enum
	if combat_zone_enum >= GameZone.e.COMBAT_OPPONENT_1 and combat_zone_enum <= GameZone.e.COMBAT_OPPONENT_3:
		# Convert opponent zone to player zone to get the view
		player_zone_enum = (combat_zone_enum - 3) as GameZone.e
	
	var combat_zone_view = game_view.get_zone_container(player_zone_enum) as CombatZone
	
	# Check if already resolved
	if combat_zone_view and game_data.is_combat_resolved(combat_zone_view):
		return
	
	# Resolve this zone's combat
	var lock = playerControlLock.addLock()
	await resolveCombatInZone(combat_zone_enum)
	if combat_zone_view:
		game_data.set_combat_resolved(combat_zone_view, true)
	playerControlLock.removeLock(lock)

func reset_all_card_turn_tracking():
	for card_data in _get_all_player_card_data():
		card_data.reset_turn_tracking()

func untap_all_player_cards():
	for card_data in _get_all_player_card_data():
		if card_data.is_tapped():
			card_data.untap()
			print("🔄 Untapped ", card_data.cardName)

func _get_all_player_card_data() -> Array[CardData]:
	"""Get all CardData for cards the player controls in play (MVC pattern - queries GameData)"""
	var all_cards: Array[CardData] = []
	
	# Query GameData for player-controlled cards in play zones
	# (battlefield + combat zones, excluding hand/deck)
	var player_zones = [
		GameZone.e.BATTLEFIELD_PLAYER,
		GameZone.e.COMBAT_PLAYER_1,
		GameZone.e.COMBAT_PLAYER_2,
		GameZone.e.COMBAT_PLAYER_3
	]
	
	for zone in player_zones:
		all_cards.append_array(game_data.get_cards_in_zone(zone))
	
	return all_cards

func _get_target_zone(target_location: Node3D) -> GameZone.e:
	"""Convert a 3D node location to a GameZone enum
	
	Note: For CombatZone, this returns a placeholder. The actual zone (player/opponent side)
	is determined in tryMoveCard based on the card's controller.
	"""
	if not target_location:
		return GameZone.e.UNKNOWN
	
	if target_location is CombatZone:
		# Return player combat zone as placeholder - actual side determined by card controller
		var zone_index = game_view.get_combat_zones().find(target_location)
		if zone_index >= 0:
			return (GameZone.e.COMBAT_PLAYER_1 + zone_index) as GameZone.e
		return GameZone.e.UNKNOWN
	elif target_location is GridContainer3D:
		# GridContainer3D used in CombatZone after refactor (for tests)
		var parent = target_location.get_parent()
		if parent is CombatZone:
			var combat_zone = parent as CombatZone
			var zone_index = game_view.get_combat_zones().find(combat_zone)
			if zone_index >= 0:
				# Determine if it's ally or opponent side
				var is_ally_side = (target_location == combat_zone.ally_side)
				if is_ally_side:
					return (GameZone.e.COMBAT_PLAYER_1 + zone_index) as GameZone.e
				else:
					return (GameZone.e.COMBAT_OPPONENT_1 + zone_index) as GameZone.e
		return GameZone.e.UNKNOWN
	elif target_location is PlayerBase:
		return GameZone.e.BATTLEFIELD_PLAYER  # TODO: distinguish player/opponent
	elif target_location == game_view.player_hand:
		return GameZone.e.HAND_PLAYER
	elif target_location == game_view.recycle_area:
		return GameZone.e.RECYCLE_ZONE
	else:
		return GameZone.e.UNKNOWN
	
func resolveCombatInZone(combat_zone: GameZone.e):
	print("🔥 === Resolving Combat in Zone ===")
	
	# MVC Pattern: Query GameData for cards in this combat zone
	# Determine if this is a player or opponent zone and get both sides
	var is_player_zone = combat_zone >= GameZone.e.COMBAT_PLAYER_1 and combat_zone <= GameZone.e.COMBAT_PLAYER_3
	var player_zone: GameZone.e
	var opponent_zone: GameZone.e
	
	if is_player_zone:
		# combat_zone is player side (8, 9, 10), opponent is +3 (11, 12, 13)
		player_zone = combat_zone
		opponent_zone = (combat_zone + 3) as GameZone.e
	else:
		# combat_zone is opponent side (11, 12, 13), player is -3 (8, 9, 10)
		opponent_zone = combat_zone
		player_zone = (combat_zone - 3) as GameZone.e
	
	# Make copies of the cards arrays to prevent issues when positions change during iteration
	var player_cards = game_data.get_cards_in_zone(player_zone).duplicate()
	var opponent_cards = game_data.get_cards_in_zone(opponent_zone).duplicate()
	print("  🐛 [DEBUG] Player cards: ", player_cards.size(), " | Opponent cards: ", opponent_cards.size())
	
	# Get CombatZone View for animations and location damage (use player zone to identify location)
	var combatZone = game_view.get_zone_container(player_zone) as CombatZone
	
	# Step 1: Mark all attacking cards as having attacked
	for card_data in player_cards:
		card_data.hasAttackedThisTurn = true
		print("⚔️ ", card_data.cardName, " is attacking")
	
	# Step 2: Emit attack_declared for each attacking card (triggers abilities like Elusive, Warchief, etc.)
	for card_data in player_cards:
		await emit_game_event(TriggeredAbility.GameEventType.ATTACK_DECLARED, card_data)
	for card_data in opponent_cards:
		await emit_game_event(TriggeredAbility.GameEventType.ATTACK_DECLARED, card_data)
	
	# Step 3: Resolve each slot's combat (match by index)
	var max_slots = max(player_cards.size(), opponent_cards.size())
	for slot_index in range(max_slots):
		var player_card_data = player_cards[slot_index] if slot_index < player_cards.size() else null
		var opponent_card_data = opponent_cards[slot_index] if slot_index < opponent_cards.size() else null
		
		if not player_card_data and not opponent_card_data:
			continue
		
		var player_damage = player_card_data.power if player_card_data else 0
		var opponent_damage = opponent_card_data.power if opponent_card_data else 0
		
		# Combat strike animations and damage
		if player_card_data and opponent_card_data:
			# Both cards strike each other
			var player_card = player_card_data.get_card_object()
			var opponent_card = opponent_card_data.get_card_object()
			if player_card and opponent_card:
				game_view.animate_combat_strike(player_card, opponent_card)
			
			# Emit strike events for triggered abilities
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, player_card_data)
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, opponent_card_data)
			
			# Apply damage
			player_card_data.receiveDamage(opponent_damage)
			opponent_card_data.receiveDamage(player_damage)
		elif player_card_data and not opponent_card_data:
			# Player attacks location directly
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, player_card_data)
			if combatZone:
				_apply_damage_to_location(player_damage, true, combatZone)
		elif opponent_card_data and not player_card_data:
			# Opponent attacks location directly
			await emit_game_event(TriggeredAbility.GameEventType.STRIKE, opponent_card_data)
			if combatZone:
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
		var damage = card_data.getDamage()
		var power = card_data.power
		
		if damage > 0 && damage >= power:
			print("  💀 [SBA] ", card_data.cardName, " is dead (damage: ", damage, " >= power: ", power, "), moving to graveyard")
			var graveyard_zone = GameZone.e.GRAVEYARD_PLAYER if card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
			await execute_move_card(card_data, graveyard_zone)
			print("  ✅ [SBA] Finished moving ", card_data.cardName, " to graveyard")
	if game_data.player_life.getValue() <= 0:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	if game_data.player_points.getValue() >= 6:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	_check_locations_capture()
	# Check and highlight castable cards
	updateDecks()
	highlightCastableCards()

func updateDecks():
	if game_data.get_cards_in_zone(GameZone.e.DECK_PLAYER).size() <= game_data.playerDeckList.deck_cards.size():
		replenish_deck_zone(GameZone.e.DECK_PLAYER)
	
	if game_data.get_cards_in_zone(GameZone.e.DECK_OPPONENT).size() <= game_data.opponentDeckList.deck_cards.size():
		replenish_deck_zone(GameZone.e.DECK_OPPONENT)

func replenish_deck_zone(zone_name: GameZone.e, copies: int = 1):
	var card_templates: Array[CardData] = []
	var is_player_owned := true

	match zone_name:
		GameZone.e.DECK_PLAYER:
			card_templates = game_data.playerDeckList.deck_cards
			is_player_owned = true
		GameZone.e.EXTRA_DECK_PLAYER:
			card_templates = game_data.playerDeckList.extra_deck_cards
			is_player_owned = true
		GameZone.e.DECK_OPPONENT:
			card_templates = game_data.opponentDeckList.deck_cards
			is_player_owned = false
		_:
			push_error("replenish_deck_zone: Unsupported deck zone " + str(zone_name))
			return

	for _i in range(copies):
		var templates_to_create: Array[CardData] = card_templates.duplicate()
		templates_to_create.shuffle()
		# Create all cards through createCardData so signal wiring and zone setup stay centralized.
		createCardDatas(templates_to_create, zone_name, is_player_owned)
	
func opponentMainOne():
	if opponent_ai:
		await opponent_ai.execute_main_phase()
	else:
		print("⚠️ OpponentAI not initialized")

static var objectCount = 0
static func getObjectCountAndIncrement():
	objectCount +=1
	return objectCount-1

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
	
	for card_data: CardData in game_data.get_cards_in_zone(GameZone.e.EXTRA_DECK_PLAYER):
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
		for card_data: CardData in game_data.get_cards_in_zone(GameZone.e.EXTRA_DECK_PLAYER):
			if CardPaymentManagerAL.isCardDataCastable(card_data):
				castable_cards.append(card_data)
		# View handles arrangement and headless check
		await game_view.arrange_extra_deck_hand(castable_cards, game_view.create_card_view)
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
		# Convert CombatZone to GameZone.e
		var combat_zone_view = objectUnderMouse.get_parent() as CombatZone
		var zone_index = game_view.get_combat_zones().find(combat_zone_view)
		if zone_index >= 0:
			var combat_zone_enum := (GameZone.e.COMBAT_PLAYER_1 + zone_index) as GameZone.e
			resolve_combat_for_zone(combat_zone_enum)
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

func start_card_selection(requirement: Dictionary, possible_cards: Array[CardData], selection_type: String, casting_card_data: CardData = null, preselected_cards: Array[CardData] = []) -> Array[CardData]:
	# If we have pre-selected cards, use them directly
	if preselected_cards.size() > 0:
		print("🎯 Using pre-selected cards for ", selection_type, ": ", preselected_cards.size(), " cards")
		return preselected_cards
	
	# If we have a casting card, set up animation and state tracking
	if casting_card_data:
		var casting_card = casting_card_data.get_card_object()
		if casting_card:
			current_casting_card = casting_card
			# Move to card selection position - using legacy method for now
			await AnimationsManagerAL.animate_card_to_card_selection_position(casting_card)
	
	# SelectionManager now takes CardData arrays and returns CardData arrays
	var selected_cards = await selection_manager.start_selection_and_wait(requirement, possible_cards, selection_type, self, casting_card_data, preselected_cards)
	
	# Clear casting state when selection completes (successfully or cancelled)
	if casting_card_data:
		current_casting_card = null
		casting_card_original_parent = null
	
	return selected_cards

## ===== UNIFIED CARD FILTER SYSTEM =====
## Single source of truth for matching cards against filter criteria.
## Used by: effects, abilities, payment logic, targeting systems.

func _matches_card_filter(filter: String) -> Array[CardData]:
	"""Return all cards from possible_cards that match the filter string.
	
	If possible_cards is empty, searches all cards in play.
	
	Filter format supports AND (+) and OR (/) logic:
	- "Creature+YouCtrl" - creatures you control (AND)
	- "Creature+NonToken/Creature+Grown-up" - (non-token creatures) OR (Grown-up creatures)
	- Conditions separated by '+' (AND logic)
	- Branches separated by '/' (OR logic)
	
	Supported tokens:
	- "Card" - always matches (generic)
	- "Creature", "Instant", "Sorcery", "Spell", etc. - card type checks
	- "YouCtrl" / "You Control" - checks if player controls this card
	- "OppCtrl" / "Opponent Control" - checks if opponent controls this card
	- "Cost.N" - checks if card cost equals N
	- "NonToken" - filters out tokens
	- "Token" - only tokens
	- "HasReplace" - cards with Replace additional cost
	- Any other token - treated as subtype check (e.g., "Goblin", "Punglynd", "Grown-up")
	"""
	var all_cards: Array = game_data.get_cards_in_play()
	var result_cards: Array[CardData] = []
	
	# Handle OR logic first - split by '/'
	var or_branches = filter.split("/")
	
	for branch in or_branches:
		var cards: Array = all_cards.duplicate()
		
		# Handle AND logic within this branch - split by '+'
		for condition in branch.split("+"):
			var tokens = condition.split(".")
			var token_index = 0
			while token_index < tokens.size():
				var key = tokens[token_index]
				
				match key:
					"", "Card":
						pass
					
					"Creature":
						cards = cards.filter(func(c): return c.hasType(CardData.CardType.CREATURE))
					
					"Instant":
						cards = cards.filter(func(c): return c.hasType(CardData.CardType.SPELL))
					
					"Spell", "Sorcery":
						cards = cards.filter(func(c): return c.hasType(CardData.CardType.SPELL))
					
					"YouCtrl", "You Control":
						cards = cards.filter(func(c): return c.playerControlled)
					
					"OppCtrl", "Opponent Control":
						cards = cards.filter(func(c): return not c.playerControlled)
					
					"Token":
						cards = cards.filter(func(c): return c.isToken)
					
					"NonToken":
						cards = cards.filter(func(c): return not c.isToken)
					
					"HasReplace":
						cards = cards.filter(func(c): return c.hasAdditionalCosts() and c.additionalCosts.any(func(cost): return cost.get("cost_type", "") == "Replace"))
					
					"Cost":
						if token_index + 1 < tokens.size():
							var target_cost = int(tokens[token_index + 1])
							cards = cards.filter(func(c): return c.goldCost == target_cost)
							token_index += 1
						else:
							cards = []
					
					_:
						cards = cards.filter(func(c): return c.hasSubtype(key))
				
				token_index += 1
		
		# Add cards from this branch to results (union of all OR branches)
		for card in cards:
			if card not in result_cards:
				result_cards.append(card)
	
	return result_cards

func _requiresPlayerSelection(additional_costs: Array[Dictionary]) -> bool:
	"""Check if any additional costs require player selection (like sacrifice)"""
	return GameUtility._requiresPlayerSelection(additional_costs)

func _collectAllPlayerSelections(card_data: CardData, pre_selections: SelectionManager.CardPlaySelections = null) -> SelectionManager.CardPlaySelections:
	"""Collect all required player selections for a card before playing it"""
	var selection_data = SelectionManager.CardPlaySelections.new()
	
	# If pre-selections are provided, use them
	if pre_selections != null:
		print("🎯 Using provided pre-selections for card play")
		return pre_selections
	
	# Step 1: Check for alternative casting options (Replace)
	var has_replace = CardPaymentManagerAL.hasReplaceOption(card_data)
	print("🔍 [REPLACE CHECK] hasReplaceOption returned: ", has_replace, " for ", card_data.cardName)
	if has_replace:
		# Get valid replacement targets for selection
		var replace_cost_data = null
		for cost_data in card_data.additionalCosts:
			if cost_data.get("cost_type", "") == "Replace":
				replace_cost_data = cost_data
				break
		
		if replace_cost_data:
			var valid_targets = CardPaymentManagerAL.getValidReplaceTargets(card_data, replace_cost_data)
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
					"replace_for_" + card_data.cardName, 
					card_data,
					preselected_replace
				)
				
				if selected_replace_target == null:
					selection_data.cancelled = true
					return selection_data
				elif selected_replace_target.size() > 0:
					selection_data.set_replace_target(selected_replace_target[0])
	
	# Step 2: Check for additional costs that require selection
	if card_data.hasAdditionalCosts():
		var additional_costs = card_data.getAdditionalCosts()
		if _requiresPlayerSelection(additional_costs):
			# Check for pre-selected sacrifice target cards
			var preselected_sacrifice: Array[CardData] = []
			if pre_selections != null and pre_selections.sacrifice_targets.size() > 0:
				preselected_sacrifice = pre_selections.sacrifice_targets
			
			var selected_cards = await _startAdditionalCostSelection(card_data, additional_costs, preselected_sacrifice)
			if selected_cards.is_empty():
				selection_data.cancelled = true
				return selection_data
			for card_selection in selected_cards:
				selection_data.add_sacrifice_target(card_selection)
	
	# Step 3: Check if spell requires targeting
	if card_data.hasType(CardData.CardType.SPELL):
		# Check for pre-selected spell targets
		var preselected_spell_targets: Array[CardData] = []
		if pre_selections != null and pre_selections.spell_targets.size() > 0:
			preselected_spell_targets = pre_selections.spell_targets
		
		var spell_targets: Array[CardData] = await _getSpellTargetsIfRequired(card_data, preselected_spell_targets)
		if spell_targets == null:  # null means selection was cancelled
			selection_data.cancelled = true
			return selection_data
		# Only check for empty targets if the spell actually requires targeting
		if spell_targets.is_empty() and _spellRequiresTargeting(card_data):
			print("❌ No valid targets available - cancelling spell")
			selection_data.cancelled = true
			return selection_data
		for target in spell_targets:
			selection_data.add_spell_target(target)
	
	return selection_data

func _spellRequiresTargeting(card_data: CardData) -> bool:
	"""Check if a spell has any effects that require targeting"""
	for ability in card_data.spell_abilities:
		if ability.requires_target():
			return true
	return false

func _getSpellTargetsIfRequired(card_data: CardData, preselected_targets: Array[CardData] = []) -> Array[CardData]:
	"""Get spell targets if the spell requires targeting, returns empty array if cancelled"""
	
	# If pre-selected targets are provided, return them
	if preselected_targets.size() > 0:
		print("🎯 Using pre-selected spell targets: ", preselected_targets.map(func(c): return c.cardName))
		return preselected_targets
	
	# Get spell abilities that require targeting
	var targeting_abilities: Array[SpellAbility] = []
	for ability in card_data.spell_abilities:
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
			for cd in cards_in_play_data:
				if cd.hasType(CardData.CardType.CREATURE):
					valid_card_data.append(cd)
		_:
			print("❌ Unknown target type: ", valid_targets)
			return []
	
	if valid_card_data.is_empty():
		print("⚠️ No valid targets for ", card_data.cardName)
		var empty_result: Array[CardData] = []
		return empty_result
	
	# Start target selection with CardData
	var requirement = {
		"valid_card": "Any",  # We've already filtered the valid_card_data
		"count": 1
	}
	
	var selected_targets = await start_card_selection(requirement, valid_card_data, "spell_target_" + card_data.cardName, card_data)
	
	if selected_targets.is_empty():
		var cancelled_result: Array[CardData] = []
		return cancelled_result  # Selection was cancelled
	
	return selected_targets

func tryPayAndSelectsForCardPlay(card_data: CardData, selection_data: SelectionManager.CardPlaySelections, pay_cost: bool = true):
	"""Execute card play with all selections already collected"""
	# Validate that the card data is valid
	if not card_data:
		print("❌ CardData is invalid")
		return
	
	# Skip payment if pay_cost is false (e.g., casting from deck via effect)
	if not pay_cost:
		print("💫 Skipping payment for card (cast via effect)")
		await _executeCardPlay(card_data, [])
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
		var dest_zone = GameZone.e.GRAVEYARD_PLAYER if sacrifice_card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
		await execute_move_card(sacrifice_card_data, dest_zone)
	
	# Convert spell targets from CardData to Card nodes for execution
	var spell_targets_data: Array[CardData] = selection_data.spell_targets
	var valid_spell_targets: Array[CardData] = []
	for target_data in spell_targets_data:
		if target_data:
			valid_spell_targets.append(target_data)
		else:
			print("⚠️ Skipping invalid spell target")
	
	await _executeCardPlay(card_data, valid_spell_targets)

func _startAdditionalCostSelection(card_data: CardData, additional_costs: Array[Dictionary], preselected_cards: Array[CardData] = []) -> Array[CardData]:
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
			for cd in cards_in_play_data:
				var card_node = cd.get_card_object()
				if card_node and is_instance_valid(card_node) and _card_matches_requirement(card_node, requirement):
					valid_card_data.append(cd)
			
			# Start the selection process with CardData
			if valid_card_data.size() > 0:
				var selected_cards = await start_card_selection(requirement, valid_card_data, "sacrifice_for_" + card_data.cardName, card_data)
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

func exchange_card_positions_in_combat(card1_data: CardData, card2_data: CardData) -> bool:
	"""Exchange positions of two cards in combat zones (GridContainer3D system)
	
	Returns true if swap was successful, false otherwise
	"""
	# Get zones for both cards
	var zone1 = game_data.get_card_zone(card1_data)
	var zone2 = game_data.get_card_zone(card2_data)
	
	# Verify both cards are in combat zones
	if not GameZone.is_combat_zone(zone1) or not GameZone.is_combat_zone(zone2):
		print("❌ Cannot exchange positions - both cards must be in combat zones")
		return false
	
	# Verify both cards are in the same combat zone
	if zone1 != zone2:
		print("❌ Cannot exchange positions - cards must be in the same combat zone")
		return false
	
	# Get indices of both cards in the zone
	var index1 = game_data.get_card_combat_index(card1_data)
	var index2 = game_data.get_card_combat_index(card2_data)
	
	if index1 == -1 or index2 == -1:
		print("❌ Cannot exchange positions - cards not found in combat zone")
		return false
	
	# Swap positions in GameData
	var cards_in_zone = game_data.get_cards_in_zone(zone1)
	cards_in_zone[index1] = card2_data
	cards_in_zone[index2] = card1_data
	
	# Update visual positions (swap Card view objects in GridContainer3D)
	var card1_view = card1_data.get_card_object()
	var card2_view = card2_data.get_card_object()
	
	if card1_view and card2_view and is_instance_valid(card1_view) and is_instance_valid(card2_view):
		var parent = card1_view.get_parent()
		if parent is GridContainer3D and card2_view.get_parent() == parent:
			# Use move_child to swap their order in the parent
			parent.move_child(card1_view, index2)
			parent.move_child(card2_view, index1)
	
	return true

func trigger_phase(phase_name: String):
	"""Trigger all phase-based abilities for a specific phase"""
	match phase_name:
		"BeginningOfTurn":
			await emit_game_event(TriggeredAbility.GameEventType.BEGINNING_OF_TURN, null)
		"EndOfTurn":
			await emit_game_event(TriggeredAbility.GameEventType.END_OF_TURN, null)
			await emit_game_event(TriggeredAbility.GameEventType.END_OF_TURN_CLEANUP, null)
			# Note: Cards no longer automatically return from combat at end of turn
		"TurnStarted":
			await emit_game_event(TriggeredAbility.GameEventType.TURN_STARTED, null)

func register_orphaned_ability(ability: TriggeredAbility):
	"""Register a triggered ability that's not attached to any card
	
	Used for delayed effects like 'Sacrifice at end of turn' created by spells.
	The ability's owner should be the spell that created it (for tracking).
	The ability will persist in play and trigger normally via signals.
	"""
	orphaned_abilities.append(ability)
	ability.register_to_game(self)
	
	var owner = ability.get_owner()
	var owner_name = owner.cardName if owner else "Unknown"
	print("🔗 [ORPHANED ABILITY] Registered: ", ability.get_description(), " (from ", owner_name, ")")

func unregister_orphaned_ability(ability: TriggeredAbility):
	"""Remove an orphaned ability and disconnect from signals"""
	if ability in orphaned_abilities:
		ability.unregister_from_game(self)
		orphaned_abilities.erase(ability)
		
		var owner = ability.get_owner()
		var owner_name = owner.cardName if owner else "Unknown"
		print("🗑️ [ORPHANED ABILITY] Unregistered: ", ability.get_description(), " (from ", owner_name, ")")

func _cleanup_one_shot_orphaned_abilities():
	"""Remove orphaned abilities marked for cleanup at end of turn
	
	This is called when END_OF_TURN_CLEANUP event fires.
	It removes any orphaned abilities that have cleanup_at_end_of_turn = true
	and haven't already been removed by one_shot.
	"""
	var to_remove: Array[TriggeredAbility] = []
	
	for ability in orphaned_abilities:
		# Check if ability has cleanup_at_end_of_turn flag
		if ability.cleanup_at_end_of_turn:
			to_remove.append(ability)
	
	for ability in to_remove:
		unregister_orphaned_ability(ability)
	
	if to_remove.size() > 0:
		print("🗑️ [ORPHANED ABILITY] Cleaned up ", to_remove.size(), " end-of-turn abilities")

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
	is_resolving_triggers = false
	print("✅ [RESOLVABLE QUEUE] Resolution complete")

func emit_game_event(event_type: TriggeredAbility.GameEventType, card_data):
	"""Emit a game event signal - abilities listening to this event will add themselves to the trigger queue"""
	match event_type:
		TriggeredAbility.GameEventType.CARD_ENTERED_PLAY:
			card_entered_play.emit(card_data)
		TriggeredAbility.GameEventType.CARD_DIED:
			card_died.emit(card_data)
		TriggeredAbility.GameEventType.ATTACK_DECLARED:
			attack_declared.emit(card_data)
		TriggeredAbility.GameEventType.CARD_DRAWN:
			# Handle both single card and array of cards
			var cards_drawn_array: Array = []
			var is_player = true
			
			if card_data is Array:
				# Multiple cards drawn (e.g., from drawCard)
				cards_drawn_array = card_data
				if cards_drawn_array.size() > 0 and cards_drawn_array[0] is CardData:
					is_player = cards_drawn_array[0].playerControlled
			elif card_data is CardData:
				# Single card drawn
				cards_drawn_array = [card_data]
				is_player = card_data.playerControlled
			
			card_drawn.emit(cards_drawn_array, is_player)
		TriggeredAbility.GameEventType.DAMAGE_DEALT:
			# Note: damage_dealt has different signature with target and amount
			pass  # This event type should not be emitted through this function
		TriggeredAbility.GameEventType.SPELL_CAST:
			spell_cast.emit(card_data)
		TriggeredAbility.GameEventType.END_OF_TURN:
			end_of_turn.emit(card_data)
		TriggeredAbility.GameEventType.END_OF_TURN_CLEANUP:
			end_of_turn_cleanup.emit()
			# Perform cleanup of orphaned abilities after signal is emitted
			_cleanup_one_shot_orphaned_abilities()
		TriggeredAbility.GameEventType.BEGINNING_OF_TURN:
			beginning_of_turn.emit(card_data)
		TriggeredAbility.GameEventType.STRIKE:
			strike.emit(card_data)
		TriggeredAbility.GameEventType.CARD_RECYCLED:
			card_recycled.emit(card_data)
	
	# After emitting the event, resolve any resolvables that were added to the queue
	await resolve_queue()

# Note: card_changed_zones is emitted directly in movement handlers, not through emit_game_event
