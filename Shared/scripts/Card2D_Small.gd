extends Control
class_name Card2D_Small

@onready var background: NinePatchRect = $Background
@onready var card_name: Label = $Background/CardName
@onready var card_art: TextureRect = $Background/CardArt
@onready var power_label: Label = $Background/powerBackground/PowerLabel
@onready var damage_label: Label = $Background/bgc/damageLabel
@onready var bgc: NinePatchRect = $Background/bgc

var card: Card

signal card_clicked(card: Card2D_Small)

func _ready():
	# Connect click signal
	gui_input.connect(_on_gui_input)

func set_card(data: Card):
	card = data
	update_display()

func update_display():
	
	if not card:
		return
	
	# Check if UI elements exist
	if not card.cardData.cardName:
		print("  - ❌ ERROR: card_name is null!")
	else:
		card_name.text = card.cardData.cardName
		
	if not power_label:
		print("  - ❌ ERROR: power_label is null!")
	else:
		power_label.text = str(card.cardData.power)
	
	# Set card art if available
	if card_art:
		if card.cardData.cardArt:
			card_art.texture = card.cardData.cardArt
	else:
		print("  - ❌ ERROR: card_art is null!")
		
	if card.damage > 0:
		bgc.show()
		damage_label.text = str(card.damage)
	else:
		bgc.hide()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
