extends Panel
class_name KeywordPanel

@onready var keyword_title: Label = $VBoxContainer/KeywordTitle
@onready var description_text: RichTextLabel = $VBoxContainer/DescriptionText

func setup_keyword(keyword: String):
	# Set up the title
	keyword_title.text = keyword
	
	# Set up the description
	var reminder_text = KeywordManager.get_keyword_text(keyword)
	description_text.text = reminder_text
	
	# Wait for the labels to calculate their sizes
	await get_tree().process_frame
	
	# Calculate total height needed
	
	# Set panel size to fit content
	custom_minimum_size = Vector2(200, 80)
