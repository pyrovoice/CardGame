extends Control
class_name AdminConsole

@onready var add_gold_button: Button = $AddPlayerGold
@onready var add_card_button: Button = $AddCardToPlayerHand
@onready var close_button: Button = $CloseButton
@onready var card_name_input: TextEdit = $TextEdit
@onready var draw_button: Button = $Draw

@export var game: Game

func _ready():
	# Connect button signals
	add_gold_button.pressed.connect(_on_add_gold_pressed)
	add_card_button.pressed.connect(_on_add_card_pressed)
	draw_button.pressed.connect(_on_draw_card)
	close_button.pressed.connect(_on_close_pressed)
	
func _on_add_gold_pressed():
	"""Set player gold to 99"""
	if game and game.game_data:
		game.game_data.player_gold.setValue(99)
		print("Admin: Set player gold to 99")

func _on_draw_card():
	game.drawCard(1)
	
func _on_add_card_pressed():
	"""Add a card to player hand based on the input text"""
	if not game:
		print("Admin Error: No game reference")
		return
	
	var card_name = card_name_input.text.strip_edges()
	if card_name.is_empty():
		print("Admin Error: No card name entered")
		return
	
	# Try to get card data using CardLoaderAL
	var card_data = CardLoaderAL.getCardByName(card_name)
	if not card_data:
		print("Admin Error: Card '", card_name, "' not found")
		return
	
	# Create card from data
	game.deck.cards.push_front(card_data)
	game.drawCard(1)
	
	# Clear the input field
	card_name_input.text = ""

func _on_close_pressed():
	"""Close the admin console"""
	hide()
