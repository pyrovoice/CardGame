extends Node3D
class_name Game

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: Node3D = $Camera3D/PlayerHand
@onready var deck: Deck = $"Deck"
@onready var combatZones: Array = [$combatZone, $combatZone2, $combatZone3]
@onready var draw: Button = $UI/draw
@onready var player_point: Label = $UI/PlayerPoint
@onready var player_life_label: Label = $UI/PlayerLife
@onready var player_shield_label: Label = $UI/PlayerShield  
@onready var danger_level_label: Label = $UI/DangerLevel
@onready var turn_label: Label = $UI/Turn
@onready var player_base: PlayerBase = $playerBase
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var card_popup: SubViewport = $cardPopup
@onready var card_in_popup: Card = $cardPopup/Card
var playerControlLock:PlayerControlLock = PlayerControlLock.new()
@onready var graveyard: Graveyard = $graveyard

# Game data and state management
var game_data: GameData

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

func _ready() -> void:
	# Initialize game data
	game_data = GameData.new()
	
	# Connect game data signals to UI updates
	game_data.player_life_changed.connect(_on_player_life_changed)
	game_data.player_shield_changed.connect(_on_player_shield_changed)
	game_data.danger_level_changed.connect(_on_danger_level_changed)
	game_data.turn_started.connect(_on_turn_started)
	
	player_control.tryMoveCard.connect(tryMoveCard)
	draw.pressed.connect(onTurnStart)
	CardLoader.load_all_cards()
	populate_deck()
	createOpposingToken()
	drawCard()
	drawCard()
	drawCard()
	
	# Initial UI update
	_update_all_ui()

func populate_deck():
	deck.cards.clear()
	deck.cards.append_array(CardLoader.cardData.duplicate())

func onTurnStart():
	# Start a new turn (increases danger level)
	game_data.start_new_turn()
	
	resolveCombats()
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
	
	# Pay costs if playing from hand
	if source_zone == GameZone.e.HAND:
		if not _payCardCosts(card):
			return
	
	# Determine target zone and execute the play
	var target_zone = _getTargetZone(target_location)
	_executeCardPlay(card, source_zone, target_zone, target_location)
	
	# If target was combat location, also execute the attack
	if target_location is CombatantFightingSpot:
		executeCardAttacks(card, target_location as CombatantFightingSpot)

func _canPlayCard(card: Card, source_zone: GameZone.e, target_location: Node3D) -> bool:
	"""Check if the card can be played to the target location"""
	# Can only play cards from hand
	if source_zone != GameZone.e.HAND:
		return false
	
	# Basic playability check
	if not isCardPlayable(card):
		return false
	
	# Check target location availability
	if target_location is CombatantFightingSpot:
		var combat_spot = target_location as CombatantFightingSpot
		if combat_spot.getCard() != null:
			# TODO: Add fallback to next available spot or PlayerBase
			return false
	
	return true

func _payCardCosts(card: Card) -> bool:
	"""Pay the costs required to play the card"""
	return payCard(card)

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
	var play_successful = moveCardToPlayerBase(card)
	
	if not play_successful:
		print("❌ Failed to play card to player base")
		return
	
	# Trigger CARD_ENTERS action after the card has moved to battlefield
	var enters_action = GameAction.new(TriggerType.Type.CARD_ENTERS, card, source_zone, GameZone.e.PLAYER_BASE)
	AbilityManagerAL.triggerGameAction(self, enters_action)

func executeCardAttacks(card: Card, combat_spot: CombatantFightingSpot):
	"""Execute card attack - move card from PlayerBase to CombatZone and trigger attack"""
	var source_zone = getCardZone(card)  # Should be PLAYER_BASE
	
	# Move the card to combat zone
	var attack_successful = moveCardToCombatZone(card, combat_spot)
	
	if not attack_successful:
		print("❌ Failed to move card to combat zone")
		return
	
	# Trigger CARD_ATTACKS action after the card has moved to combat zone
	var attacks_action = GameAction.new(TriggerType.Type.CARD_ATTACKS, card, source_zone, GameZone.e.COMBAT_ZONE)
	AbilityManagerAL.triggerGameAction(self, attacks_action)
	
func isCardPlayable(card: Card):
	return player_hand.get_children().find(card) != -1
	
func payCard(card: Card):
	return true
	
func moveCardToCombatZone(card: Card, zone: CombatantFightingSpot) -> bool:
	zone.setCard(card)
	card.animatePlayedTo(zone.global_position + Vector3(0, 0.1, 0))
	return true

func moveCardToPlayerBase(card: Card) -> bool:
	var target_position = player_base.getNextEmptyLocation()
	if target_position == Vector3.INF:  # No empty location available
		return false
	
	# Convert local position to global position
	var global_target = player_base.global_position + target_position
	card.reparent(player_base)
	card.animatePlayedTo(global_target + Vector3(0, 0.1, 0))
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
		
		card.setRotation(Vector3(90, 0, 0), 0)


func resolveCombats():
	var lock = playerControlLock.addLock()
	for cv in combatZones:
		resolveCombatInZone(cv)
	playerControlLock.removeLock(lock)
	
func resolveCombatInZone(combatZone: CombatZone):
	var damageCounter = 0
	for i in range(1, 4):
		var allyCard = combatZone.getCardSlot(i, true).getCard()
		var oppCard = combatZone.getCardSlot(i, false).getCard()
		if allyCard && oppCard:
			allyCard.receiveDamage(oppCard.getPower())
			oppCard.receiveDamage(allyCard.getPower())
		elif allyCard && !oppCard:
			damageCounter += allyCard.getPower()
		elif !allyCard && oppCard:
			damageCounter -= oppCard.getPower()
	resolveStateBasedAction()
	if combatZone.getTotalStrengthForSide(true) > combatZone.getTotalStrengthForSide(false):
		player_point.text = str(player_point.text.to_int()+1)

func resolveStateBasedAction():
	for c:Card in getAllCardsInPlay():
		if c.getDamage() >= c.getPower():
			putInOwnerGraveyard(c)
			
func createOpposingToken():
	var card = CARD.instantiate()
	add_child(card)
	card.setData(CardData.new("Ennemy", 0, CardData.CardType.CREATURE, 3, ""))
	var location = combatZones[0].getFirstEmptyLocation(false)
	if location:
		location.setCard(card, false)
	card.makeSmall()

func getAllCardsInPlay() -> Array[Card]:
	var cards:Array[Card] = player_base.getCards()
	for cz:CombatZone in combatZones:
		cz.allySpots.filter(func(c:CombatantFightingSpot): return c.getCard() != null).map(func(c:CombatantFightingSpot): cards.push_back(c.getCard()))
	return cards 

func putInOwnerGraveyard(card: Card):
	await card.animatePlayedTo(graveyard.global_position)
	graveyard.cards.push_back(card.cardData)
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
		
		# Default fallback
	return GameZone.e.DECK

# UI Update Functions
func _update_all_ui():
	"""Update all UI elements with current game state"""
	if game_data:
		_on_player_life_changed(game_data.player_life)
		_on_player_shield_changed(game_data.player_shield)
		_on_danger_level_changed(game_data.danger_level)
		_on_turn_started(game_data.current_turn)

func _on_player_life_changed(new_life: int):
	"""Update player life display"""
	if player_life_label:
		player_life_label.text = "Life: " + str(new_life)
	print("Player Life: ", new_life)

func _on_player_shield_changed(new_shield: int):
	"""Update player shield display"""
	if player_shield_label:
		player_shield_label.text = "Shield: " + str(new_shield)
	print("Player Shield: ", new_shield)

func _on_danger_level_changed(new_level: int):
	"""Update danger level display"""
	if danger_level_label:
		danger_level_label.text = "Danger: " + str(new_level)
	print("Danger Level: ", new_level)

func _on_turn_started(turn_number: int):
	"""Update turn display"""
	if turn_label:
		turn_label.text = "Turn: " + str(turn_number)
	print("Turn Started: ", turn_number)

# Game Data Access Functions
func get_game_data() -> GameData:
	"""Get the current game data"""
	return game_data

func damage_player(amount: int):
	"""Apply damage to the player"""
	if game_data:
		game_data.damage_player(amount)

func heal_player(amount: int):
	"""Heal the player"""
	if game_data:
		game_data.heal_player(amount)

func restore_shield(amount: int):
	"""Restore player shield"""
	if game_data:
		game_data.restore_shield(amount)

func is_game_over() -> bool:
	"""Check if the game is over (player defeated)"""
	return game_data and game_data.is_player_defeated()
