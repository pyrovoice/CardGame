# Deck.gd
extends Node3D
class_name Deck

@onready var deck_mesh: MeshInstance3D = $deckMesh
var cards: Array = [] #CardData; 0 is topmost card
const CARD = preload("res://Game/scenes/Card.tscn")

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
	return (get_parent() as Game).createCardFromData(card_data)
	
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
