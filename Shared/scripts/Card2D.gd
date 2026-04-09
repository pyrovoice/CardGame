extends Control
class_name Card2D

@onready var background: NinePatchRect = $Background
@onready var card_art: TextureRect = $Background/CardArt
@onready var type_label: Label = $Background/TypeLabel
@onready var text_label: RichTextLabel = $Background/TextLabel
@onready var cost_label: Label = $Background/costBackground/CostLabel
@onready var power_label: Label = $Background/TextureRect/PowerLabel
@onready var name_label: AutoSizeLabel = $Background/ColorRect/NameLabel

var cardData: CardData
var scroll_tween: Tween  # For animated text scrolling

signal card_clicked(card: Card2D)
signal card_right_clicked(card_data: CardData)

func _ready():
	update_display()

func set_card(data: CardData):
	cardData = data
	# If we're already ready, update immediately; otherwise wait for _ready
	if name_label: # If onready vars are available, we can update now
		update_display()

func update_display():
	if not cardData:
		return
	
	# At this point, if we're being called, the UI elements should be ready
	# If they're not, there's a structural problem with the scene
	if not name_label:
		push_error("Card2D: UI elements are null. Check that the scene structure matches the @onready variable paths.")
		return
		
	name_label.text = cardData.cardName
	cost_label.text = str(cardData.goldCost)
	type_label.text = cardData.getFullTypeString()
	power_label.text = str(cardData.power)
	
	# Set card art if available
	if cardData.cardArt:
		card_art.texture = cardData.cardArt
	
	# Process text with keyword formatting
	text_label.text = format_text_with_keywords(cardData)

func format_text_with_keywords(data: CardData) -> String:
	var formatted_text = ""
	
	# Prepend keywords from the keywords array (keywords appear first)
	var keywords_list = data.keywords  # Use property accessor to get keywords with temp effects
	if keywords_list.size() > 0:
		var keyword_texts: Array[String] = []
		for keyword in keywords_list:
			keyword_texts.append(keyword.capitalize())
		formatted_text = " ".join(keyword_texts) + "."
	
	# Add the main card text after keywords
	var main_text = data.text_box
	main_text = main_text.replace("\n", "[p]")
	main_text = main_text.replace("CARDNAME", data.cardName)
	
	if not main_text.is_empty():
		if not formatted_text.is_empty():
			formatted_text += "[p]"
		formatted_text += main_text
	
	# Highlight all known keywords from KeywordManager
	for keyword in KeywordManager.keywords.keys():
		# Simply replace the keyword with bold version
		# This will find the keyword anywhere it appears as a whole word
		formatted_text = formatted_text.replace(keyword, "[outline_size=3][color=#705E05]" + keyword + "[/color][/outline_size]")
	
	return formatted_text

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(cardData)

func _on_mouse_entered():
	modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	modulate = Color.WHITE

func animate_text_scroll(direction: int, scroll_step: int = 50) -> bool:
	"""Animate scrolling of the text label. Direction: -1 for up, 1 for down. Returns true if scrolling occurred."""
	if not text_label:
		return false
	
	var v_scroll = text_label.get_v_scroll_bar()
	if not v_scroll:
		return false
	
	# Stop any existing scroll animation
	if scroll_tween:
		scroll_tween.kill()
	
	# Calculate target scroll position
	var current_value = v_scroll.value
	var target_value
	
	if direction < 0:  # Scroll up
		target_value = max(0, current_value - scroll_step)
	else:  # Scroll down
		target_value = min(v_scroll.max_value, current_value + scroll_step)
	
	# Only animate if there's actually movement to be done
	if target_value == current_value:
		return false
	
	# Create smooth scrolling animation
	scroll_tween = create_tween()
	scroll_tween.tween_property(v_scroll, "value", target_value, 0.15)
	scroll_tween.set_ease(Tween.EASE_OUT)
	scroll_tween.set_trans(Tween.TRANS_QUART)
	
	return true
