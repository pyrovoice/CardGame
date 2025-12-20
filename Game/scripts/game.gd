extends Node3D
class_name Game

const OpponentAIScript = preload("res://Game/scripts/OpponentAI.gd")

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
# Game data and state management
var game_data: GameData
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
	"""Set the active hand for PlayerControl to interact with"""
	activeHand = hand
	player_control.activeHand = hand


# Casting state tracking
var current_casting_card: Card = null
var casting_card_original_parent: Node = null

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

func _ready() -> void:
	# Initialize game data
	game_data = GameData.new()
	# Initialize activeHand to default player_hand
	activeHand = player_hand
	# Set PlayerControl reference to activeHand
	player_control.activeHand = activeHand
	game_data.playerDeckList.deck_cards = [CardLoaderAL.getCardByName("Goblin Emblem"), 
		CardLoaderAL.getCardByName("Punglynd Childbearer"),
		CardLoaderAL.getCardByName("Goblin Warchief"),
		CardLoaderAL.getCardByName("Goblin Pair"),
		CardLoaderAL.getCardByName("Bolt")
		]
	game_data.playerDeckList.extra_deck_cards = CardLoaderAL.extraDeckCardData.duplicate(true)
	game_data.opponentDeckList.deck_cards = CardLoaderAL.opponentCards.duplicate(true)
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
	populate_decks()
	await drawCard(5, true)
	await drawCard(3, false)
	await onTurnStart(true)
	
func populate_decks():
	refilLDeck(deck, game_data.playerDeckList.deck_cards.duplicate(true), true)
	refilLDeck(deck, game_data.playerDeckList.deck_cards.duplicate(true), true)
	refilLDeck(extra_deck, game_data.playerDeckList.extra_deck_cards.duplicate(true), true)
	refilLDeck(deck_opponent, game_data.opponentDeckList.deck_cards.duplicate(true), false)

func onTurnStart(skipFirstTurn = false):
	# Start a new turn (increases danger level via SignalInt)
	if !skipFirstTurn:
		await resolve_unresolved_combats()
		# Trigger end of turn phase
		trigger_phase("EndOfTurn")
		# Clean up temporary effects that last until end of turn
		cleanup_end_of_turn_effects()
		game_data.start_new_turn()
		reset_all_card_turn_tracking()
		# Untap all player cards at start of turn
		untap_all_player_cards()
		game_data.reset_combat_resolution_flags()
		# Trigger beginning of turn phase
		trigger_phase("BeginningOfTurn")
	await drawCard()
	@warning_ignore("integer_division")
	await drawCard(game_data.danger_level.getValue()/3, false)
	game_data.setOpponentGold()
	await opponent_ai.execute_main_phase()

func tryMoveCard(card: Card, target_location: Node3D) -> void:
	"""Attempt to move a card to the specified location - handles different movement types based on source zone"""
	if not card:
		return
	
	# Default to PlayerBase if no target specified
	if not target_location:
		target_location = player_base
	
	var source_zone = getCardZone(card)
	var target_zone = _get_target_zone(target_location)
	
	match source_zone:
		GameZone.e.HAND, GameZone.e.EXTRA_DECK:
			# Playing from hand - use the full play logic
			tryPlayCard(card, target_location)
		
		GameZone.e.PLAYER_BASE:
			# Moving from PlayerBase to combat - this is an attack
			if target_location is CombatantFightingSpot:
				executeCardAttacks(card, target_location as CombatantFightingSpot)
			else:
				print("❌ Cannot move card from PlayerBase to non-combat location")
		
		GameZone.e.COMBAT_ZONE:
			# Moving from combat back to PlayerBase - retreat/return
			
			if target_location is PlayerBase:
				if (source_zone == GameZone.e.PLAYER_BASE and target_zone == GameZone.e.COMBAT_ZONE) or \
				   (source_zone == GameZone.e.COMBAT_ZONE and target_zone == GameZone.e.PLAYER_BASE):
					if can_card_move(card):
						moveCardToPlayerBase(card)
			elif source_zone == GameZone.e.COMBAT_ZONE and \
			 card.get_parent().get_parent() == target_location.get_parent():
				exchange_card_in_spots(card.get_parent(), target_location)
			else:
				print("❌ Cannot move card from CombatZone to non-PlayerBase location")
				# Reset card to rest state when move fails
				card.getAnimator().go_to_rest()
		
		_:
			print("❌ Cannot move card from zone: ", source_zone)
	
func tryPlayCard(card: Card, target_location: Node3D, pre_selections: SelectionManager.CardPlaySelections = null) -> void:
	"""Attempt to play a card to the specified location with optional pre-specified selections"""
	if not card:
		return
	
	var source_zone = getCardZone(card)
	
	# Validate the play attempt
	if not _canPlayCard(card, source_zone):
		return
	
	# Use CardPlaySelections directly
	var selection_data: SelectionManager.CardPlaySelections
	if pre_selections != null and pre_selections.has_selections():
		print("🎯 Using pre-specified selections for card play")
		selection_data = pre_selections
	else:
		selection_data = null
	
	# Only process additional selections if playing from hand or extra deck
	if source_zone == GameZone.e.HAND or source_zone == GameZone.e.EXTRA_DECK:
		var correct_hand
		if card.cardData.playerControlled:
			if source_zone == GameZone.e.HAND:
				correct_hand = player_hand
			elif source_zone == GameZone.e.EXTRA_DECK:
				correct_hand = extra_hand
		else:
			correct_hand = opponent_hand
		current_casting_card = card
		casting_card_original_parent = correct_hand
		
		GameUtility.reparentCardWithoutMovingRepresentation(card, self)
		
		# Move card to cast preparation position to show casting has started
		await card.getAnimator().cast_position(card.is_facedown).finished
		if !card.cardData.playerControlled:
			await get_tree().create_timer(0.5).timeout
		
		# Collect all required player selections upfront (including casting choice)
		if selection_data == null:
			selection_data = await _collectAllPlayerSelections(card)
		else:
			print("🎯 Skipping selection collection - using pre-specified selections")
		
		# If any selection was cancelled, abort the play
		if selection_data.cancelled:
			_restore_cancelled_card()
			return
		
		# Execute the card play with all collected selections
		await tryPayAndSelectsForCardPlay(card, source_zone, target_location, selection_data)
	# If target was combat location, also execute the attack
	if target_location is CombatantFightingSpot:
		await executeCardAttacks(card, target_location as CombatantFightingSpot)

func _canPlayCard(card: Card, source_zone: GameZone.e) -> bool:
	"""Check if the card can be played to the target location"""
	# Can play cards from hand or extra deck
	var can_play_from_zone = (source_zone == GameZone.e.HAND) or (source_zone == GameZone.e.EXTRA_DECK)
	if not can_play_from_zone:
		return false
	
	return CardPaymentManagerAL.canPayCard(card)  
	
func _executeCardPlay(card: Card, source_zone: GameZone.e, _target_location: Node3D, spell_targets: Array):
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
	resolveStateBasedAction()

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
		# Effects that require targeting
		if effect_type in ["DealDamage", "Pump", "Destroy", "Bounce", "Exile"] and target_index < targets.size():
			effect_targets = [targets[target_index]]
			target_index += 1
		
		await _executeSpellEffectWithTargets(card, effect, effect_targets)
	
	print("✨ Finished casting spell: ", card.cardData.cardName)

func _executeSpellEffectWithTargets(card: Card, effect: Dictionary, targets: Array):
	"""Execute a single spell effect with pre-selected targets - delegates to AbilityManager"""
	# Convert spell effect format to ability format and use unified execution
	var ability = {
		"type": "SpellEffect",
		"effect_type": effect.get("effect_type", ""),
		"effect_parameters": effect.get("parameters", {}),
		"target_conditions": {}
	}
	
	# For targeting effects, add targets to parameters
	if targets.size() > 0:
		ability.effect_parameters["Targets"] = targets
	
	# Use the unified ability execution system
	await AbilityManagerAL.executeAbilityEffect(card, ability, self)

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
	
	if combat_spot.getCard():
		combat_spot = (combat_spot.get_parent() as CombatZone).getFirstEmptyLocation(card.cardData.playerControlled)
	
	if combat_spot == null:
		print("No empty slot found" + card.name + " of " + str(card.cardData.playerControlled))
		return
	# Move the card to combat zone
	var attack_successful = moveCardToCombatZone(card, combat_spot)
	
	if not attack_successful:
		print("❌ Failed to move card to combat zone")
		return
	
	# Trigger CARD_ATTACKS action after the card has moved to combat zone
	var attacks_action = GameAction.new(TriggerType.Type.CARD_ATTACKS, card, source_zone, GameZone.e.COMBAT_ZONE)
	AbilityManagerAL.triggerGameAction(self, attacks_action)
	
	# Resolve state-based actions after attack
	resolveStateBasedAction()
	

func moveCardToCombatZone(card: Card, zone: CombatantFightingSpot) -> bool:
	# Check if card can be tapped (required for movement)
	if not card.cardData.can_tap():
		print("❌ Cannot move card - already tapped: ", card.cardData.cardName)
		return false
	
	# Tap the card for movement and mark as attacked
	card.cardData.tap()
	card.cardData.hasAttackedThisTurn = true
	
	# Let setCard handle the positioning and reparenting
	zone.setCard(card)
	return true

func moveCardToPlayerBase(card: Card, require_tap: bool = true) -> Tween:
	"""Move card to PlayerBase with smooth animation from current position
	
	Args:
		card: The card to move
		require_tap: If true, card must be tappable and will be tapped (for movement actions).
		             If false, card is entering battlefield and doesn't need to tap.
	"""
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:  # No empty location available
		return null
	
	# Only check tapping for actual movement actions (not initial battlefield entry)
	if require_tap:
		# Check if card can be tapped (required for movement)
		if not card.cardData.can_tap():
			print("❌ Cannot move card - already tapped: ", card.cardData.cardName)
			return null
		
		# Tap the card for movement
		card.cardData.tap()
	
	# Use local position since card will be reparented to player_base
	var local_target = target_position + Vector3(0, 0.2, 0)
	
	# Use the enhanced animate_card_to_position with reparenting
	return card.getAnimator().move_to_position(local_target, 0.8, player_base)

func drawCard(howMany: int = 1, player = true):
	var _deck = deck if player else deck_opponent
	var cards = _deck.draw_card_from_top(howMany)
	var hand = player_hand if player else opponent_hand
	
	# Store deck position for animations
	var deck_position = _deck.global_position
	
	# Add all cards to hand at once - this triggers arrange_cards_fan
	# which positions existing cards and sets logical positions for new cards
	hand.arrange_cards_fan(cards)
	
	# Keep all newly added cards' representations at deck position
	for card in cards:
		card.card_representation.global_position = deck_position
	
	# Now animate each card with 0.2s delay between them
	var draw_position = Vector3(0, 2, 1)
	for i in range(cards.size()):
		var card = cards[i]
		var animator = card.getAnimator()
		
		# Calculate offset for multiple cards (spread them out during draw)
		var spacing = 0.56
		var offset = Vector3(-(spacing * (cards.size() - 1)) / 2 + spacing * i, 0, 0)
		var target_draw_pos = draw_position + offset
		
		# Use draw animation with 0.2s delay between cards
		animator.draw_card(
			deck_position,                # from_position
			target_draw_pos,              # draw_position  
			card.global_position,             # final_position (hand position + card local position)
			i * 0.1,                      # delay of 0.2s between cards
			player and card.is_facedown   # flip_card
		)
	
	# Wait for all animations to complete (longest delay + animation time)
	await get_tree().create_timer(cards.size() * 0.2 + 0.6).timeout
	
	# Resolve state-based actions after drawing card
	var action = GameAction.new(TriggerType.Type.CARD_DRAWN, null, GameZone.e.DECK, GameZone.e.HAND, {"cards" = cards})
	AbilityManagerAL.triggerGameAction(self, action)
	resolveStateBasedAction()

func resolveCombats():
	var lock = playerControlLock.addLock()
	for cv in combatZones:
		await resolveCombatInZone(cv)
	playerControlLock.removeLock(lock)

func resolve_unresolved_combats():
	"""Resolve combat only in zones that haven't been resolved yet"""
	var lock = playerControlLock.addLock()
	for cld in game_data.combatLocationDatas:
		if !cld.isCombatResolved.value:
			await resolve_combat_for_zone(cld.relatedLocation)
	
	playerControlLock.removeLock(lock)

func resolve_combat_for_zone(combat_zone: CombatZone):
	"""Handle when a specific combat zone requests resolution"""
	
	# Check if already resolved
	if game_data.is_combat_resolved(combat_zone):
		return
	
	# Resolve this zone's combat
	var lock = playerControlLock.addLock()
	await resolveCombatInZone(combat_zone)
	game_data.set_combat_resolved(combat_zone, true)
	playerControlLock.removeLock(lock)

func reset_all_card_turn_tracking():
	"""Reset all turn-based tracking for all player cards (movement, attacks, etc.)"""
	for card in _get_all_player_cards():
		card.cardData.reset_turn_tracking()

func untap_all_player_cards():
	"""Untap all player cards at the start of turn"""
	for card in _get_all_player_cards():
		if card.cardData.is_tapped():
			card.cardData.untap()
			print("🔄 Untapped ", card.cardData.cardName)

func cleanup_end_of_turn_effects():
	"""Remove all temporary effects that last until end of turn from all cards"""
	print("🧹 Cleaning up end of turn effects...")
	
	var total_effects_removed = 0
	
	# Check all player cards for temporary effects
	for card in _get_all_player_cards():
		var effects_to_remove = card.cardData.get_temporary_effects_by_duration("EndOfTurn")
		
		if effects_to_remove.size() > 0:
			print("  🗑️ Removing ", effects_to_remove.size(), " effect(s) from ", card.cardData.cardName)
			
			for effect in effects_to_remove:
				_remove_temporary_effect_from_card(card, effect)
				total_effects_removed += 1
	
	if total_effects_removed > 0:
		print("  ✅ Removed ", total_effects_removed, " end-of-turn effect(s) total")

func _remove_temporary_effect_from_card(card: Card, effect: Dictionary):
	"""Remove a specific temporary effect from a card"""
	var effect_type = effect.get("type")
	
	match effect_type:
		"keyword":
			_remove_keyword_from_card(card, effect.get("keyword"))
		"type":
			_remove_type_from_card(card, effect.get("type_to_remove"))
		"power_boost":
			_remove_power_boost_from_card(card, effect.get("power_bonus"))
		_:
			print("    ❌ Unknown temporary effect type: ", effect_type)
	
	# Remove from card's tracking
	card.cardData.clear_temporary_effect(effect)

func _remove_keyword_from_card(card: Card, keyword: String):
	"""Remove a granted keyword ability from a card"""
	# Find and remove the keyword ability
	var abilities_to_remove = []
	for i in range(card.cardData.abilities.size()):
		var ability = card.cardData.abilities[i]
		if ability.get("type") == "KeywordAbility" and ability.get("keyword") == keyword and ability.get("granted_by") == "ActivatedAbility":
			abilities_to_remove.append(i)
	
	# Remove abilities in reverse order to maintain indices
	abilities_to_remove.reverse()
	for index in abilities_to_remove:
		card.cardData.abilities.remove_at(index)
	
	# Update the card's visual display
	if card.has_method("updateDisplay"):
		card.updateDisplay()

func _remove_type_from_card(card: Card, type_to_remove: String):
	"""Remove a granted type/subtype from a card"""
	# Check if it's a main type or subtype
	if CardData.isValidCardTypeString(type_to_remove):
		# It's a main card type - remove it
		var card_type = CardData.stringToCardType(type_to_remove)
		card.cardData.removeType(card_type)
	else:
		# It's a subtype - remove it
		card.cardData.subtypes.erase(type_to_remove)
	
	# Update the card's visual display
	if card.has_method("updateDisplay"):
		card.updateDisplay()

func _remove_power_boost_from_card(card: Card, power_bonus: int):
	"""Remove a temporary power boost from a card"""
	print("    💪 Removing +", power_bonus, " power boost from ", card.cardData.cardName)
	
	# Reverse the power boost
	card.cardData.power -= power_bonus
	
	print("      Power now: ", card.cardData.power)
	
	# Update the card's visual display
	if card.has_method("updateDisplay"):
		card.updateDisplay()
	
	# Emit dirty signal to update UI
	card.cardData.emit_signal("dirty_data")

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
	for slot_index in range(1, 4):
		var player_card = combatZone.getCardSlot(slot_index, true).getCard()
		var opponent_card = combatZone.getCardSlot(slot_index, false).getCard()
		if not player_card and not opponent_card:
			return
		var player_damage = player_card.getPower() if player_card else 0
		var opponent_damage = opponent_card.getPower() if opponent_card else 0
		var player_strike
		var opponent_strike
		if player_card and opponent_card:
			player_strike = player_card.getAnimator().animate_combat_strike(opponent_card)
			opponent_strike = opponent_card.getAnimator().animate_combat_strike(player_card)
			await player_strike.finished
			await opponent_strike.finished
			player_card.receiveDamage(opponent_damage)
			opponent_card.receiveDamage(player_damage)
		if player_card and not opponent_card:
			_apply_damage_to_location(player_damage, true, combatZone)
		elif opponent_card and not player_card:
			_apply_damage_to_location(opponent_damage, false, combatZone)
			
	resolveStateBasedAction()

func _apply_damage_to_location(damage: int, is_player_damage: bool, combatZone: CombatZone):
	"""Apply damage to location capture values"""
	if damage <= 0:
		return
	game_data.add_location_capture_value(damage, is_player_damage, combatZone)
	
	# Show floating text animation
	var damage_text = "+" + str(damage) + " Capture"
	var damage_color = Color.BLUE if is_player_damage else Color.RED
	AnimationsManagerAL.show_floating_text(self, combatZone.global_position, damage_text, damage_color)

func _check_locations_capture():
	"""Check if any location has been captured based on capture thresholds"""
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
	var cards_in_play = getAllCardsInPlay()
	
	for c:Card in cards_in_play:
		var damage = c.getDamage()
		var power = c.getPower()
		
		if damage > 0 && damage >= power:
			putInOwnerGraveyard(c)
	if game_data.player_life.getValue() <= 0:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	if game_data.player_points.getValue() >= 6:
		get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
	_check_locations_capture()
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
			GameUtility.reparentCardWithoutMovingRepresentation(card, self)
			card.getAnimator().move_to_position(graveyard.global_position)
	
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
	
func createCardFromData(cardData: CardData, player_controlled: bool):
	return GameUtility.createCardFromData(self, cardData, player_controlled, false)

func createToken(cardData: CardData, player_controlled: bool) -> Card:
	"""Create a token card and execute its enters-the-battlefield effects"""
	return GameUtility.createCardFromData(self, cardData, player_controlled, true)

func executeCardEnters(card: Card, source_zone: GameZone.e, target_zone: GameZone.e):
	"""Execute the card entering the battlefield - handles movement and triggers"""
	# Move the card to player base (no tapping required for battlefield entry)
	card.setFlip(true)
	card.getAnimator().make_small()
	var tween = moveCardToPlayerBase(card, false)  # false = don't require tap for entering battlefield
	
	if not tween:
		print("❌ Failed to move card to player base")
		return
	else:
		await tween.finished
	# Trigger CARD_ENTERS action after the card has moved to battlefield
	var enters_action = GameAction.new(TriggerType.Type.CARD_ENTERS, card, source_zone, target_zone)
	AbilityManagerAL.triggerGameAction(self, enters_action)
	
	# Resolve state-based actions after card enters
	resolveStateBasedAction()

func getCardZone(card: Card) -> GameZone.e:
	"""Determine what zone a card is currently in based on its parent and controller"""
	return GameUtility.getCardZone(self, card)

func get_highlight_manager() -> HighlightManager:
	"""Get the highlight manager for direct access"""
	return highlightManager

func connect_card_to_highlight_manager(card: Card):
	"""Connect a card's animator to the highlight manager for drag notifications"""
	if highlightManager:
		highlightManager.connect_to_card_animator(card)

# Helper functions for finding cards by control/ownership
func getAllPlayerControlledCards() -> Array[Card]:
	"""Get all cards currently controlled by the player"""
	var all_cards = getAllCardsInPlay()
	return all_cards.filter(func(card): return card.cardData.playerControlled)

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
	var activated_abilities = []
	for ability in card.cardData.abilities:
		if ability.get("type") == "ActivatedAbility":
			activated_abilities.append(ability)
	
	if activated_abilities.is_empty():
		return false
	
	# For now, if there are multiple activated abilities, use the first one
	# TODO: Add UI to choose between multiple abilities
	var ability_to_activate = activated_abilities[0]
	
	# Check if the ability can be activated (costs can be paid)
	if not AbilityManagerAL.canPayActivationCosts(card, ability_to_activate, self):
		print("❌ Cannot pay activation costs for ", card.cardData.cardName)
		return false
	
	print("🔥 Activating ability on ", card.cardData.cardName)
	
	# Activate the ability
	await AbilityManagerAL.activateAbility(card, ability_to_activate, self)
	
	return true

func _on_left_click(objectUnderMouse):
	if objectUnderMouse is Card:
		var card = objectUnderMouse as Card
		
		# Handle card selection if we're in a selection process
		if selection_manager.is_selecting():
			selection_manager.handle_card_click(card)
		else:
			# Check for activated abilities first
			if await tryActivateAbility(card):
				return
			# If no activated abilities, fall back to normal behavior (like showing popup)
			# For now, we don't do anything else on left-click for cards
	elif objectUnderMouse is ResolveFightButton:
		resolve_combat_for_zone(objectUnderMouse.get_parent())
	elif objectUnderMouse == extra_deck:
		# Clicked on extra deck - show the extra deck view
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

func start_card_selection(requirement: Dictionary, possible_cards: Array[Card], selection_type: String, casting_card: Card = null, preselected_cards: Array[Card] = []) -> Array[Card]:
	# If we have pre-selected cards, use them directly
	if preselected_cards.size() > 0:
		print("🎯 Using pre-selected cards for ", selection_type, ": ", preselected_cards.size(), " cards")
		return preselected_cards
	
	# If we have a casting card, set up animation and state tracking
	if casting_card:
		current_casting_card = casting_card
		# Move to card selection position - using legacy method for now
		await AnimationsManagerAL.animate_card_to_card_selection_position(casting_card)
	
	# Start the selection process
	var selected_cards = await selection_manager.start_selection_and_wait(requirement, possible_cards, selection_type, self, casting_card, preselected_cards)
	
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
	
	# Debug logging for Punglynd Childbearer
	if card.cardData.cardName == "Punglynd Childbearer":
		print("🔍 [PUNGLYND DEBUG] Starting selection collection for ", card.cardData.cardName)
		print("🔍 [PUNGLYND DEBUG] Can pay card (current check): ", CardPaymentManagerAL.canPayCard(card))
	
	# Step 1: Check for alternative casting options (Replace)
	var has_replace = CardPaymentManagerAL.hasReplaceOption(card)
	if has_replace:
		print("🎯 [CASTING CHOICE] Card ", card.cardData.cardName, " has Replace option available!")
		if card.cardData.cardName == "Punglynd Childbearer":
			print("🔍 [PUNGLYND DEBUG] ✅ Replace option confirmed available")
		
		# Get valid replacement targets for selection
		var replace_cost_data = null
		for cost_data in card.cardData.additionalCosts:
			if cost_data.get("cost_type", "") == "Replace":
				replace_cost_data = cost_data
				break
		
		if replace_cost_data:
			var valid_targets = CardPaymentManagerAL.getValidReplaceTargets(card, replace_cost_data)
			if valid_targets.size() > 0:
				# TODO: Show CastChoice.tscn UI here - for now use selection manager
				var requirement = {
					"valid_card": "Any", # Already filtered
					"count": 1,
					"optional": true # Player can choose nothing to cast normally
				}
				
				# Check if we have pre-selected replace target
				var preselected_replace: Array[Card] = []
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
					print("🎯 [CASTING CHOICE] Player chose Replace with: ", selected_replace_target[0].cardData.cardName)
				else:
					print("🎯 [CASTING CHOICE] Player chose normal casting")
		else:
			print("🎯 [CASTING CHOICE] Card ", card.cardData.cardName, " has no alternative casting options")
	
	# Step 2: Check for additional costs that require selection
	if card.cardData.hasAdditionalCosts():
		var additional_costs = card.cardData.getAdditionalCosts()
		if _requiresPlayerSelection(additional_costs):
			# Check for pre-selected sacrifice target cards
			var preselected_sacrifice: Array[Card] = []
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
		var preselected_spell_targets: Array[Card] = []
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
	for ability in card.cardData.abilities:
		if ability.get("type") == "SpellEffect":
			var effect_type = ability.get("effect_type", "")
			# Check if this effect type requires targeting
			if effect_type in ["DealDamage", "Pump", "Destroy", "Bounce", "Exile"]:
				return true
	return false

func _getSpellTargetsIfRequired(card: Card, preselected_targets: Array[Card] = []) -> Variant:
	"""Get spell targets if the spell requires targeting, returns null if cancelled"""
	
	# If pre-selected targets are provided, return them
	if preselected_targets.size() > 0:
		print("🎯 Using pre-selected spell targets: ", preselected_targets.map(func(c): return c.cardData.cardName))
		return preselected_targets
	
	# Get spell effects that require targeting
	var targeting_effects = []
	for ability in card.cardData.abilities:
		if ability.get("type") == "SpellEffect":
			var effect_type = ability.get("effect_type", "")
			# Check if this effect type requires targeting
			if effect_type in ["DealDamage", "Pump", "Destroy", "Bounce", "Exile"]:
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

func tryPayAndSelectsForCardPlay(card: Card, source_zone: GameZone.e, target_location: Node3D, selection_data: SelectionManager.CardPlaySelections):
	"""Execute card play with all selections already collected"""
	# Validate that the card is still valid
	if not card or not is_instance_valid(card) or not card.cardData:
		print("❌ Card is invalid or freed")
		return
	
	# Pay costs first
	var sacrifice_targets: Array[Card] = selection_data.sacrifice_targets
	
	# Validate Replace casting choice if selected
	if selection_data.replace_target != null:
		var replace_target = selection_data.replace_target
		if not is_instance_valid(replace_target):
			print("❌ Replace target is invalid")
			return
		
		# Verify the card actually has Replace option
		if not CardPaymentManagerAL.hasReplaceOption(card):
			print("❌ Card does not have Replace option")
			return
		
		# Verify the target is valid for Replace
		if not CardPaymentManagerAL.isValidReplaceTarget(card, replace_target):
			print("❌ Replace target is not valid for this card")
			return
		
		# Verify we can afford the Replace cost
		var replace_cost = CardPaymentManagerAL.calculateReplaceCost(card, replace_target)
		if not game_data.has_gold(replace_cost, card.cardData.playerControlled):
			print("❌ Cannot afford Replace cost: ", replace_cost)
			return
		
		print("💰 [REPLACE PAYMENT] Using Replace - sacrificing: ", replace_target.cardData.cardName, " (cost: ", replace_cost, ")")
	
	# Validate sacrifice target cards are still valid before payment
	var valid_sacrifice_cards: Array[Card] = []
	for cost_card in sacrifice_targets:
		if cost_card and is_instance_valid(cost_card) and cost_card.cardData:
			valid_sacrifice_cards.append(cost_card)
		else:
			print("⚠️ Skipping invalid sacrifice target card")
	
	# Pay for the card - include Replace target if using Replace
	var payment_successful = false
	if selection_data.replace_target != null:
		# Add Replace target for payment processing
		var payment_cards = valid_sacrifice_cards.duplicate()
		payment_cards.append(selection_data.replace_target)
		payment_successful = await CardPaymentManagerAL.tryPayCard(card, payment_cards)
	else:
		payment_successful = await CardPaymentManagerAL.tryPayCard(card, valid_sacrifice_cards)
	
	if not payment_successful:
		print("❌ Failed to pay for card")
		return
	
	# Determine target zone and execute the play
	var spell_targets: Array[Card] = []
	if selection_data.spell_targets != null:
		spell_targets.assign(selection_data.spell_targets)
	
	# Validate spell targets are still valid
	var valid_spell_targets: Array[Card] = []
	for target_card in spell_targets:
		if target_card and is_instance_valid(target_card) and target_card.cardData:
			valid_spell_targets.append(target_card)
		else:
			print("⚠️ Skipping invalid spell target")
	
	await _executeCardPlay(card, source_zone, target_location, valid_spell_targets)

func _startAdditionalCostSelection(card: Card, additional_costs: Array[Dictionary], preselected_cards: Array[Card] = []) -> Array[Card]:
	"""Start the selection process for paying additional costs and return selected cards"""
	
	# If pre-selected cards are provided, return them
	if preselected_cards.size() > 0:
		print("🎯 Using pre-selected additional cost cards: ", preselected_cards.map(func(c): return c.cardData.cardName))
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

func can_card_move(card: Card) -> bool:
	if card.cardData.is_tapped():
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
	var phase_action = GameAction.new(TriggerType.Type.PHASE)
	phase_action.additional_data = {"phase": phase_name}
	AbilityManagerAL.triggerGameAction(self, phase_action)
	
	# Handle end of turn special logic
	if phase_name == "EndOfTurn":
		await end_of_turn_return_cards_to_base()

func end_of_turn_return_cards_to_base():
	"""Return all player-controlled cards from combat locations to playerBase"""
	var cards_to_return: Array[Card] = []
	
	# Collect all player cards in combat zones
	for combat_zone in combatZones:
		for ally_spot in combat_zone.allySpots:
			var card = ally_spot.getCard()
			if card and card.cardData.playerControlled:
				cards_to_return.append(card)
	
	# Return cards to player base - they will untap at start of next turn
	for card in cards_to_return:
		# First remove from combat spot by reparenting to game temporarily
		GameUtility.reparentWithoutMoving(card, self)
		
		# Then move to player base using a simple position animation (don't use moveCardToPlayerBase as it requires tapping)
		var target_position = player_base.getNextEmptyLocation()
		if target_position != Vector3.INF:
			var local_target = target_position + Vector3(0, 0.2, 0)
			card.getAnimator().move_to_position(local_target, 0.8, player_base)
	
	# Wait a moment for animations to start
	await get_tree().create_timer(0.1).timeout
	
	print("🔄 End of turn: Returned ", cards_to_return.size(), " cards to player base")
