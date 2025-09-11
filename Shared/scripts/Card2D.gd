extends Control
class_name Card2D

@onready var background: NinePatchRect = $Background
@onready var card_art: TextureRect = $Background/CardArt
@onready var name_label: Label = $Background/NameLabel
@onready var type_label: Label = $Background/TypeLabel
@onready var text_label: RichTextLabel = $Background/TextLabel
@onready var cost_label: Label = $Background/costBackground/CostLabel
@onready var power_label: Label = $Background/TextureRect/PowerLabel

var card: Card

signal card_clicked(card: Card2D)
signal card_right_clicked(card_data: CardData)

func _ready():
	update_display()

func set_card(data: Card):
	card = data
	# If we're already ready, update immediately; otherwise wait for _ready
	if name_label: # If onready vars are available, we can update now
		update_display()

func update_display():
	if not card:
		return
	
	# At this point, if we're being called, the UI elements should be ready
	# If they're not, there's a structural problem with the scene
	if not name_label:
		push_error("Card2D: UI elements are null. Check that the scene structure matches the @onready variable paths.")
		return
		
	name_label.text = card.cardData.cardName
	cost_label.text = str(card.cardData.goldCost)
	type_label.text = card.cardData.getFullTypeString()
	power_label.text = str(card.cardData.power)
	
	# Set card art if available
	if card.cardData.cardArt:
		card_art.texture = card.cardData.cardArt
	
	# Process text with keyword formatting
	text_label.text = format_text_with_keywords(card.cardData)

func format_text_with_keywords(data: CardData) -> String:
	var formatted_text = data.text_box
	# First, replace newlines with BBCode line breaks
	# Try both common BBCode line break formats
	formatted_text = formatted_text.replace("\n", "[p]")
	formatted_text = formatted_text.replace("CARDNAME", data.cardName)
	
	# Get all known keywords from KeywordManager
	for keyword in KeywordManager.keywords.keys():
		# Simply replace the keyword with bold version
		# This will find the keyword anywhere it appears as a whole word
		formatted_text = formatted_text.replace(keyword, "[color=GOLDENROD]" + keyword + "[/color]")
	
	return formatted_text

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(card.card_data)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
