extends Node3D
class_name Game

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: Node3D = $Camera3D/PlayerHand
@onready var deck: Deck = $"Deck"
@onready var combatZones: Array = [$combatZone, $combatZone2, $combatZone3]
@onready var draw: Button = $UI/draw
@onready var player_point: Label = $UI/PlayerPoint
@onready var player_base: PlayerBase = $playerBase
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var card_popup: SubViewport = $cardPopup
@onready var card_in_popup: Card = $cardPopup/Card
var playerControlLock:PlayerControlLock = PlayerControlLock.new()
@onready var graveyard: Graveyard = $graveyard

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

func _ready() -> void:
	player_control.tryMoveCard.connect(tryPlayCard)
	draw.pressed.connect(onTurnStart)
	CardLoader.load_all_cards()
	populate_deck()
	createOpposingToken()
	drawCard()
	drawCard()
	drawCard()

func populate_deck():
	deck.cards.clear()
	deck.cards.append_array(CardLoader.cardData.duplicate())

func onTurnStart():
	resolveCombats()
	drawCard()
	createOpposingToken()
	
func tryPlayCard(card: Card, _location: Node3D) -> bool:
	if !_location:
		return false
	var cardZone = getCardZone(card)
	if cardZone == GameZone.e.HAND:
		if isCardPlayable(card):
			if !payCard(card):
				return false
	if _location is CombatantFightingSpot:
		if (_location as CombatantFightingSpot).getCard() != null:
			return false
		var played = playCardToCombatZone(card, _location)
		# Trigger CARD_PLAYED event (for enters-the-battlefield effects)
		var played_action = GameAction.new(GameAction.TriggerType.CARD_PLAYED, card, cardZone, GameZone.e.COMBAT_ZONE)
		AbilityManagerAL.triggerGameAction(self, played_action)
		return played
	elif _location is PlayerBase:
		var played = playCardToPlayerBase(card)
		# Trigger CARD_PLAYED event (for enters-the-battlefield effects)
		var played_action = GameAction.new(GameAction.TriggerType.CARD_PLAYED, card, cardZone, GameZone.e.PLAYER_BASE)
		AbilityManagerAL.triggerGameAction(self, played_action)
		return played
	return false
	
	
func isCardPlayable(card: Card):
	return player_hand.get_children().find(card) != -1
	
func payCard(card: Card):
	return true
	
func playCardToCombatZone(card: Card, zone: CombatantFightingSpot):
	zone.setCard(card)
	card.animatePlayedTo(zone.global_position + Vector3(0, 0.1, 0))
	return true

func playCardToPlayerBase(card: Card) -> bool:
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
	var action = GameAction.new(GameAction.TriggerType.CARD_DRAWN, card, GameZone.e.DECK, GameZone.e.HAND)
	AbilityManagerAL.triggerGameAction(self, action)
	
	arrange_cards_fan()

func arrange_cards_fan():
	var cards = player_hand.get_children()
	var count = cards.size()
	if count == 0:
		return
	
	var max_angle_deg = 0.02 * count   # Total fan spread angle (degrees)
	var spacing = 0.3        # Horizontal space between cards
	
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
		card.position.z = i *0.02  # optional: slight z offset for layering if needed
		card.position.y = -0.005 * pow(i - ((count - 1) / 2.0), 2)
		
		var angle_deg = lerp(max_angle_deg, -max_angle_deg, i / float(max(1.0, count - 1)))
		card.setRotation(Vector3(90, 0, 0), angle_deg)


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
