# Deck.gd
extends Node3D
class_name Deck

@onready var deck_mesh: MeshInstance3D = $deckMesh
var cards: Array = [] #CardData; 0 is topmost card
@export var deck_size := 10
const CARD = preload("res://Game/scenes/Card.tscn")

func _ready():
	populate_deck()

func populate_deck():
	cards.clear()
	for i in range(deck_size):
		var card = CardData.new()
		card.cardName = "CardName %d" % i
		card.power = 2
		# other properties use defaults from _init
		add_card(card)

# Add cards to the deck
func add_card(card_data):
	cards.append(card_data)

# Shuffle the deck using Fisher-Yates
func shuffle():
	var n := cards.size()
	for i in range(n - 1, 0, -1):
		var j := randi() % (i + 1)
		var temp = cards[i]
		cards[i] = cards[j]
		cards[j] = temp

# Draw and instantiate the top card, then remove it from the deck
func draw_card_from_top() -> Card:
	var card_data: CardData = cards.pop_front()
	if card_data == null:
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
	card_instance.setData(card_data)
	return card_instance

# Peek at the top N card data (does not remove or instantiate)
func get_cards_from_top(n: int) -> Array:
	return cards.slice(0, min(n, cards.size()))

# Adjusts the height of the CardMesh based on the number of cards
func update_size():
	if deck_mesh:
		var base_height = 0.02 
		var new_height = max(0.01, cards.size() * base_height)
		(deck_mesh.mesh as BoxMesh).size.y = new_height
		deck_mesh.position.y = new_height/2
