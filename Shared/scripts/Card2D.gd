extends Control
class_name Card2D

@onready var background: NinePatchRect = $Background
@onready var card_art: TextureRect = $Background/CardArt
@onready var name_label: Label = $Background/NameLabel
@onready var cost_label: Label = $Background/CostLabel
@onready var type_label: Label = $Background/TypeLabel
@onready var power_label: Label = $Background/PowerLabel
@onready var text_label: RichTextLabel = $Background/TextLabel

var card_data: CardData

signal card_clicked(card: Card2D)

func _ready():
	gui_input.connect(_on_gui_input)
	set_card_data(CardLoader.getRandomCard())

func set_card_data(data: CardData):
	card_data = data
	update_display()

func update_display():
	if not card_data:
		return
		
	name_label.text = card_data.cardName
	cost_label.text = str(card_data.cost)
	type_label.text = card_data.getFullTypeString()
	power_label.text = str(card_data.power)
	text_label.text = card_data.text_box

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
