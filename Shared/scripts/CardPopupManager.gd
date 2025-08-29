extends Control
class_name CardPopupManager

@onready var card_popup_display: TextureRect = $CardPopupDisplay
@onready var card_popup_viewport: SubViewport = $CardPopupViewport
@onready var keyword_container: VBoxContainer = $KeywordContainer
# Remove the static card reference - we'll create fresh ones each time
var card_in_popup: Card = null

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

func show_card_popup(card_data: CardData, popup_position: Vector2 = Vector2.ZERO):
	if not card_data:
		return
	
	# Clear any existing card in the viewport
	clear_popup_card()
	
	# Create a fresh Card instance
	var card_scene = preload("res://Game/scenes/Card.tscn")
	card_in_popup = card_scene.instantiate()
	card_popup_viewport.add_child(card_in_popup)
	
	# Set the card data
	card_in_popup.setData(card_data)
	
	# Force viewport to update and render the new card
	card_popup_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame  # Wait one frame for the card to update
	
	# Show the popup display
	card_popup_display.show()
	card_popup_display.texture = card_popup_viewport.get_texture()
	card_popup_display.visible = true
	
	# Position the popup
	if popup_position != Vector2.ZERO:
		card_popup_display.global_position = popup_position
	else:
		# Center on screen if no position provided
		var viewport_size = get_viewport().get_visible_rect().size
		card_popup_display.global_position = (viewport_size - card_popup_display.size) / 2
	
	# Show keyword reminder panels for each keyword
	create_keyword_panels(card_data)
	
	# Animate the popup
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
	card_popup_display.hide()
	clear_keyword_panels()
	clear_popup_card()  # Clear the card when hiding
	popup_closed.emit()

func animate_popup_show():
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	card_popup_display.scale = Vector2.ZERO
	current_tween.tween_property(card_popup_display, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
