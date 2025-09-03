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
signal card_right_clicked(card_data: CardData)

func _ready():
	gui_input.connect(_on_gui_input)
	# Only set random card data if no data was already provided
	if not card_data:
		set_card_data(CardLoader.getRandomCard())
	else:
		# If card_data was set before _ready, update display now
		update_display()

func set_card_data(data: CardData):
	card_data = data
	# If we're already ready, update immediately; otherwise wait for _ready
	if name_label: # If onready vars are available, we can update now
		update_display()

func update_display():
	if not card_data:
		return
	
	# At this point, if we're being called, the UI elements should be ready
	# If they're not, there's a structural problem with the scene
	if not name_label or not cost_label or not type_label or not power_label or not text_label:
		push_error("Card2D: UI elements are null. Check that the scene structure matches the @onready variable paths.")
		return
		
	name_label.text = card_data.cardName
	cost_label.text = str(card_data.cost)
	type_label.text = card_data.getFullTypeString()
	power_label.text = str(card_data.power)
	
	# Set card art if available
	if card_data.cardArt:
		card_art.texture = card_data.cardArt
	else:
		# Clear the texture if no art is available
		card_art.texture = null
	
	# Process text with keyword formatting
	text_label.text = format_text_with_keywords(card_data)

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
			card_right_clicked.emit(card_data)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE
