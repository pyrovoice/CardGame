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

# Get card count from GameData (not local array)
func get_card_count() -> int:
	if zone_name == GameZone.e.UNKNOWN or not get_parent():
		return 0
	var game = _find_game()
	if game and game.game_data:
		return game.game_data.get_cards_in_zone(zone_name).size()
	return 0

func _find_game() -> Game:
	# Player/opponent decks are direct children of Game; per-Lieutenant decks sit inside a combat zone
	var node: Node = self
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	return null

# Override update_size to adjust the height of the CardMesh based on GameData card count
func update_size():
	var card_count_value = get_card_count()
	var base_height = 0.02 
	var new_height = max(0.01, card_count_value * base_height)
	(deck_mesh.mesh as BoxMesh).size.y = new_height
	card_count.text = str(card_count_value)
	cover.position.y = new_height/2 + 0.01
	card_count.position.y = new_height/2 + 0.03
