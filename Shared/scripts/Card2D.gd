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
	
	# Process text with keyword formatting
	text_label.text = format_text_with_keywords(card_data.text_box)

func format_text_with_keywords(text: String) -> String:
	# Enable BBCode processing
	if text_label:
		text_label.bbcode_enabled = true
	
	var formatted_text = text
	
	# Get all known keywords from KeywordManager
	for keyword in KeywordManager.keywords.keys():
		# Simply replace the keyword with bold version
		# This will find the keyword anywhere it appears as a whole word
		formatted_text = formatted_text.replace(keyword, "[b]" + keyword + "[/b]")
	
	return formatted_text

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
