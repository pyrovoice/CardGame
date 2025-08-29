extends Control
class_name KeywordReminderPanel

@onready var v_box_container: VBoxContainer = $Background/VBoxContainer
@onready var background: Panel = $Background

var keyword_labels: Array[Control] = []

func _ready():
	visible = false

func show_keywords_for_card(card_data: CardData):
	clear_keywords()
	
	if not card_data:
		hide()
		return
	
	# Parse keywords from the card text
	var keywords = KeywordManager.parse_keywords_from_text(card_data.text_box)
	
	if keywords.size() == 0:
		hide()
		return
	
	# Create UI elements for each keyword
	for keyword in keywords:
		create_keyword_entry(keyword)
	
	# Show the panel
	visible = true

func create_keyword_entry(keyword: String):
	# Single label for both keyword and reminder text
	var keyword_label = RichTextLabel.new()
	keyword_label.bbcode_enabled = true
	
	var reminder_text = KeywordManager.get_keyword_text(keyword)
	keyword_label.text = "[color=black][b]" + keyword + ":[/b] " + reminder_text + "[/color]"
	
	keyword_label.fit_content = true
	keyword_label.custom_minimum_size = Vector2(260, 20)
	keyword_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	v_box_container.add_child(keyword_label)
	keyword_labels.append(keyword_label)

func clear_keywords():
	for label in keyword_labels:
		if label and is_instance_valid(label):
			label.queue_free()
	keyword_labels.clear()

func position_next_to_card(card_popup_rect: TextureRect):
	if not card_popup_rect:
		return
	
	# Position the panel to the right of the card popup
	var card_rect = card_popup_rect.get_rect()
	var card_pos = card_popup_rect.global_position
	
	global_position.x = card_pos.x + card_rect.size.x + 10  # 10px margin
	global_position.y = card_pos.y

func hide_panel():
	visible = false
