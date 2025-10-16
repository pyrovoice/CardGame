extends CardContainer
class_name Deck

@onready var card_count: Label3D = $cardCount
@onready var deck_mesh: MeshInstance3D = $deckMesh
const CARD = preload("res://Game/scenes/Card.tscn")
@onready var cover: MeshInstance3D = $cover

func _ready():
	is_hidden_for_owner = true
	is_hidden_for_opponent = true  
	update_size()
	
# Override add_card to call parent and update size
func add_card(card_data: CardData):
	super.add_card(card_data)

# Shuffle the deck using Fisher-Yates
func shuffle():
	var n := cards.size()
	for i in range(n - 1, 0, -1):
		var j := randi() % (i + 1)
		var temp = cards[i]
		cards[i] = cards[j]
		cards[j] = temp

# Draw and instantiate the top card, then remove it from the deck
func draw_card_from_top(howMany = 1) -> Array[Card]:
	var cardsDrawn:Array[Card] = []
	for i in range(0, howMany):
		cardsDrawn.push_back(draw_specific_card(cards[howMany-i]))
	return cardsDrawn
	
# Peek at the top N card data (does not remove or instantiate)
func get_cards_from_top(n: int) -> Array:
	return cards.slice(0, min(n, cards.size()))

# Override update_size to adjust the height of the CardMesh based on the number of cards
func update_size():
	var base_height = 0.02 
	var new_height = max(0.01, cards.size() * base_height)
	(deck_mesh.mesh as BoxMesh).size.y = new_height
	card_count.text = str(cards.size())
	cover.position.y = new_height/2 +0.01
	card_count.position.y = new_height/2 +0.03
