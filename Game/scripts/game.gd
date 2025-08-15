extends Node3D

@onready var player_control: PlayerControl = $playerControl
@onready var player_hand: Node3D = $Camera3D/PlayerHand
@onready var deck: Deck = $"Deck"
@onready var combat_zone: CombatZone = $combatZone
@onready var combat_zone_2: CombatZone = $combatZone2
@onready var combat_zone_3: CombatZone = $combatZone3
@onready var draw: Button = $UI/draw
@onready var player_point: Label = $UI/PlayerPoint
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var card_popup: SubViewport = $cardPopup
@onready var card_in_popup: Card = $cardPopup/Card

func _ready() -> void:
	player_control.tryPlayCard.connect(tryPlayCard)
	draw.pressed.connect(onTurnStart)
	createOpposingToken()
	drawCard()
	drawCard()
	drawCard()

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
		card.position.z = (i - count/2)*0.02  # optional: slight z offset for layering if needed
		card.position.y = -0.005 * pow(i - ((count - 1) / 2.0), 2)
		
		# Calculate rotation for fan effect:
		# Angle from -max_angle/2 to +max_angle/2 degrees across cards
		var angle_deg = lerp(max_angle_deg, -max_angle_deg, i / float(max(1.0, count - 1)))
		card.setRotation(Vector3(90, 0, 0), angle_deg)

func resolveCombats():
	resolveCombatInZone(combat_zone)
	resolveCombatInZone(combat_zone_2)
	resolveCombatInZone(combat_zone_3)
	
func resolveCombatInZone(combatZone: CombatZone):
	var totalAllies = combat_zone.getTotalStrengthForSide(true)
	var totalOpponenents = combat_zone.getTotalStrengthForSide(false)
	if (totalAllies >= totalOpponenents):
		player_point.text = str(int(player_point.text) +1)
	
func createOpposingToken():
	var card = CARD.instantiate()
	add_child(card)
	card.setData(CardData.new("Ennemy", 0, CardData.CardType.CREATURE, 3, ""))
	combat_zone.getFirstEmptyLocation(false).setCard(card, false)
	card.makeSmall()

	
