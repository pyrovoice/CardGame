extends Panel
class_name KeywordPanel

@onready var label: RichTextLabel = $RichTextLabel

func setup_keyword(keyword: String):
	# Set up the label content
	var reminder_text = KeywordManager.get_keyword_text(keyword)
	label.text = "[b]" + keyword + "[/b]: " + reminder_text
	
	# Wait for the label to calculate its size
	await get_tree().process_frame
	var content_height = label.get_content_height()
	
	# Set panel size to fit content
	custom_minimum_size = Vector2(260, max(content_height + 10, 25))
