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
	var game = get_parent() as Game
	if game and game.game_data:
		match zone_name:
			GameZone.e.DECK_PLAYER:
				return game.game_data.cards_in_deck_player.size()
			GameZone.e.DECK_OPPONENT:
				return game.game_data.cards_in_deck_opponent.size()
			GameZone.e.EXTRA_DECK_PLAYER:
				return game.game_data.cards_in_extra_deck_player.size()
	return 0

# Override update_size to adjust the height of the CardMesh based on GameData card count
func update_size():
	var card_count_value = get_card_count()
	var base_height = 0.02 
	var new_height = max(0.01, card_count_value * base_height)
	(deck_mesh.mesh as BoxMesh).size.y = new_height
	card_count.text = str(card_count_value)
	cover.position.y = new_height/2 + 0.01
	card_count.position.y = new_height/2 + 0.03
