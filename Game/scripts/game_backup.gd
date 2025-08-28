extends Node3D

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: Node3D = $Camera3D/PlayerHand
@onready var deck: Deck = $"Deck"
@onready var combatZones: Array = [$combatZone, $combatZone2, $combatZone3]
@onready var draw: Button = $UI/draw
@onready var player_point: Label = $UI/PlayerPoint
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var card_popup: SubViewport = $cardPopup
@onready var card_in_popup: Card = $cardPopup/Card
var playerControlLock:PlayerControlLock = PlayerControlLock.new()
@onready var graveyard: Graveyard = $graveyard

# Card library loaded from files
var loaded_card_data: Array[CardData] = []

func _ready() -> void:
	player_control.tryPlayCard.connect(tryPlayCard)
	draw.pressed.connect(onTurnStart)
	CardLoader.load_all_cards()
	populate_deck()
	createOpposingToken()
	drawCard()
	drawCard()
	drawCard()

func populate_deck():
	deck.cards.clear()
	for i in range(10):
		deck.add_card(CardLoader.getRandomCard())

func onTurnStart():
	resolveCombats()
	drawCard()
	createOpposingToken()
	
func tryPlayCard(card: Card, _location: Node3D) -> bool:
	if !_location || !(_location is CombatantFightingSpot) || (_location as CombatantFightingSpot).getCard() != null:
		return false
		
	if isCardPlayable(card):
		if payCard(card):
			return playCard(card, _location)
	return false
	
	
func isCardPlayable(card: Card):
	return player_hand.get_children().find(card) != -1
	
func payCard(card: Card):
	return true
	
func playCard(card: Card, zone: CombatantFightingSpot):
	zone.setCard(card)
	card.animatePlayedTo(zone.global_position + Vector3(0, 0.1, 0))
	
	# Trigger card played abilities (like Goblin Matron)
	var cards_on_battlefield = getAllCardsInPlay()
	AbilityManager.trigger_card_played_abilities(
		cards_on_battlefield,
		card,
		["is_owner_player:true"],
		self
	)
	
	# Trigger zone change abilities for the card being played (Hand -> Battlefield)
	AbilityManager.trigger_zone_change_abilities(
		cards_on_battlefield,
		card,
		["origin:Hand", "destination:Battlefield"],
		self
	)
	
	return true

func drawCard():
	var card = deck.draw_card_from_top()
	if card == null:
		return
	card.reparent(player_hand, false)
	arrange_cards_fan()

func arrange_cards_fan():
	var cards = player_hand.get_children()
	var count = cards.size()
	if count == 0:
		return
	
	var max_angle_deg = 0.02 * count   # Total fan spread angle (degrees)
	var spacing = 0.3        # Horizontal space between cards
	
	# If only 1 card, center it
	if count == 1:
		var card = cards[0]
		card.position = Vector3(0, 0, 0)
		card.rotation = Vector3(0, 0, 0)
		return
		
	# Calculate positions for multiple cards
	var start_x = -(count - 1) * spacing / 2
	var start_angle_deg = -max_angle_deg / 2
	
	for i in range(count):
		var card = cards[i]
		var t = float(i) / float(count - 1) if count > 1 else 0  # Normalize to 0-1
		
		# Position
		var x = start_x + i * spacing
		card.position = Vector3(x, 0, 0)
		
		# Rotation (convert degrees to radians)
		var angle_deg = start_angle_deg + t * max_angle_deg
		var angle_rad = deg_to_rad(angle_deg)
		card.rotation = Vector3(0, 0, angle_rad)

func resolveCombats():
	for combatZone:CombatZone in combatZones:
		var allyCard:Card = combatZone.getAllyCard()
		var enemyCard:Card = combatZone.getEnemyCard()
		var damageCounter = 0
		if allyCard && enemyCard:
			damageCounter = allyCard.cardData.power
			enemyCard.takeDamage(damageCounter)
			allyCard.takeDamage(enemyCard.cardData.power)
			if allyCard.cardData.power <= 0:
				putInOwnerGraveyard(allyCard)
			if enemyCard.cardData.power <= 0:
				putInOwnerGraveyard(enemyCard)

func createOpposingToken():
	var card = CARD.instantiate()
	add_child(card)
	card.setData(CardData.new("Ennemy", 0, CardData.CardType.CREATURE, 3, ""))
	var location = combatZones[0].getFirstEmptyLocation(false)
	if location:
		location.setCard(card, false)
	card.makeSmall()

func getAllCardsInPlay() -> Array:
	var cards = []
	for cz:CombatZone in combatZones:
		cz.allySpots.filter(func(c:CombatantFightingSpot): return c.getCard() != null).map(func(c:CombatantFightingSpot): cards.push_back(c.getCard()))
	return cards 

func putInOwnerGraveyard(card: Card):
	# Trigger zone change abilities for cards going to graveyard
	var cards_on_battlefield = getAllCardsInPlay()
	AbilityManager.trigger_zone_change_abilities(
		cards_on_battlefield,
		card,
		["origin:Battlefield", "destination:Graveyard"],
		self
	)
	
	await card.animatePlayedTo(graveyard.global_position)
	graveyard.cards.push_back(card.cardData)
	card.queue_free()
