extends Control
class_name Card2D_Small

@onready var background: NinePatchRect = $Background
@onready var card_name: Label = $Background/CardName
@onready var card_art: TextureRect = $Background/CardArt
@onready var power_label: Label = $Background/powerBackground/PowerLabel

var card_data: CardData

signal card_clicked(card: Card2D_Small)

func _ready():
	# Connect click signal
	gui_input.connect(_on_gui_input)

func set_card_data(data: CardData):
	card_data = data
	update_display()

func update_display():
	
	if not card_data:
		return
	
	# Check if UI elements exist
	if not card_name:
		print("  - ❌ ERROR: card_name is null!")
	else:
		card_name.text = card_data.cardName
		
	if not power_label:
		print("  - ❌ ERROR: power_label is null!")
	else:
		power_label.text = str(card_data.power)
	
	# Set card art if available
	if card_art:
		if card_data.cardArt:
			card_art.texture = card_data.cardArt
		else:
			# Clear the texture if no art is available
			card_art.texture = null
	else:
		print("  - ❌ ERROR: card_art is null!")

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
