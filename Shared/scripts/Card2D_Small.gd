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
		
	card_name.text = card_data.cardName
	power_label.text = str(card_data.power)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
