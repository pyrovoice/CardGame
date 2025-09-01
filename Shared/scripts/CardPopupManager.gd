extends Control
class_name CardPopupManager

# Display modes for card popup
enum DisplayMode {
	NORMAL,
	ENLARGED
}

# Display configuration constants
const NORMAL_SCALE = Vector2.ONE
const ENLARGED_SCALE = Vector2(1.5, 1.5)
const KEYWORD_GAP_NORMAL = 20
const KEYWORD_GAP_ENLARGED = 5

@onready var keyword_container: VBoxContainer = $KeywordContainer
# Use Card2D instead of 3D card and viewport
var card_in_popup: Card2D = null

var current_tween: Tween = null
var keyword_panels: Array[Control] = []

signal popup_closed()

func _ready():
	# Initially hide everything
	hide_popup()
	
	# Connect input events to handle closing
	set_process_input(true)

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		# Close popup on any mouse click
		hide_popup()

func show_card_popup(card_data: CardData, popup_position: Vector2 = Vector2.ZERO, display_mode: DisplayMode = DisplayMode.NORMAL):
	if not card_data:
		return
	
	# Clear any existing card
	clear_popup_card()
	
	# Configure scale and keyword gap based on display mode
	var card_scale = ENLARGED_SCALE if display_mode == DisplayMode.ENLARGED else NORMAL_SCALE
	var keyword_gap = KEYWORD_GAP_ENLARGED if display_mode == DisplayMode.ENLARGED else KEYWORD_GAP_NORMAL
	
	# Create a fresh Card2D instance
	var card_scene = preload("res://Shared/scenes/Card2D.tscn")
	card_in_popup = card_scene.instantiate() as Card2D
	add_child(card_in_popup)
	
	# Set the card data
	card_in_popup.set_card_data(card_data)
	
	# Scale the card for display mode
	card_in_popup.scale = card_scale
	
	# Show the card
	card_in_popup.visible = true
	
	# Position the popup
	if popup_position != Vector2.ZERO:
		card_in_popup.global_position = popup_position
	else:
		# Center on screen if no position provided
		var screen_size = get_viewport().get_visible_rect().size
		var card_size = card_in_popup.size * card_scale
		card_in_popup.global_position = (screen_size - card_size) / 2
	
	# Create keyword panels first
	create_keyword_panels(card_data)
	
	# Position keyword container based on card position
	if popup_position != Vector2.ZERO:
		# Position keywords to the right of the card when specific position is given
		var card_width = card_in_popup.size.x * card_scale.x
		var keyword_x_pos = popup_position.x + card_width + keyword_gap
		keyword_container.global_position = Vector2(keyword_x_pos, popup_position.y)
	else:
		# Default positioning when centered - keywords to the right of card
		var screen_size = get_viewport().get_visible_rect().size
		var card_size = card_in_popup.size * card_scale
		var keyword_x_pos = (screen_size.x - card_size.x) / 2 + card_size.x + keyword_gap
		var keyword_y_pos = (screen_size.y - card_size.y) / 2
		keyword_container.global_position = Vector2(keyword_x_pos, keyword_y_pos)
	
	# Animate the popup (no scaling, just fade/size animation)
	animate_popup_show()

func clear_popup_card():
	# Remove any existing card from the viewport
	if card_in_popup and is_instance_valid(card_in_popup):
		card_in_popup.get_parent().remove_child(card_in_popup)
		card_in_popup.queue_free()
		card_in_popup = null

func create_keyword_panels(card_data: CardData):
	# Clear any existing panels first
	clear_keyword_panels()
	
	if not card_data:
		return
	
	# Parse keywords from the card text
	var keywords = KeywordManager.parse_keywords_from_text(card_data.text_box)
	
	if keywords.size() == 0:
		return
	
	# Create a panel for each keyword
	for keyword in keywords:
		create_single_keyword_panel(keyword)

func create_single_keyword_panel(keyword: String):
	# Load and instantiate the keyword panel scene
	var keyword_panel_scene = preload("res://Shared/scenes/KeywordPanel.tscn")
	var panel = keyword_panel_scene.instantiate()
	keyword_container.add_child(panel)
	# Set up the keyword content
	await panel.setup_keyword(keyword)
	
	# Add to container
	keyword_panels.append(panel)

func clear_keyword_panels():
	for panel in keyword_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	keyword_panels.clear()

func hide_popup():
	if card_in_popup and is_instance_valid(card_in_popup):
		card_in_popup.hide()
	clear_keyword_panels()
	clear_popup_card()  # Clear the card when hiding
	popup_closed.emit()

func animate_popup_show():
	if current_tween:
		current_tween.kill()
	
	if card_in_popup and is_instance_valid(card_in_popup):
		current_tween = create_tween()
		card_in_popup.modulate.a = 0.0
		current_tween.tween_property(card_in_popup, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
