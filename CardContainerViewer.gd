extends Node2D
class_name CardContainerViewer

@onready var card_container: HBoxContainer = $Panel/ScrollContainer/HBoxContainer
@onready var scroll_container: ScrollContainer = $Panel/ScrollContainer

var cards: Array[CardData] = []
var card_instances: Array[Card2D] = []
var current_center_index: int = 0

# Mouse drag tracking
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_start_scroll: float = 0.0
const DRAG_THRESHOLD: float = 5.0  # Minimum pixels to start drag

# Preload the Card2D scene
const CARD_2D_SCENE = preload("res://Shared/scenes/Card2D.tscn")

const CARD_SPACING: float = 150.0  # Horizontal spacing between cards
const CENTER_SCALE: float = 1.0    # Full size for center card
const NEAR_SCALE: float = 0.7      # Cards 1-2 positions away
const FAR_SCALE: float = 0.3       # Cards 3+ positions away
const COVERED_AMOUNT: float = 0.9  # How much cards overlap (90%)

signal viewer_closed

func _ready():
	for i in range(0, 10):
		cards.append(CardLoaderAL.getRandomCard())
	
	# Connect to scroll changes
	scroll_container.get_h_scroll_bar().value_changed.connect(_on_scroll_changed)
	
	# For testing: display the cards immediately
	_create_card_instances()
	_update_card_positions_from_scroll()

func show_cards(card_list: Array[CardData], title: String = "Cards"):
	cards = card_list
	_clear_cards()
	_create_card_instances()
	_update_card_positions_from_scroll()
	show()

func _clear_cards():
	for card in card_instances:
		card.queue_free()
	card_instances.clear()

func _create_card_instances():
	for i in range(cards.size()):
		var card_data = cards[i]
		
		# Instantiate a Card2D scene
		var card_2d = CARD_2D_SCENE.instantiate() as Card2D
		card_2d.set_card(card_data)
		
		# Set custom minimum size if needed
		card_2d.custom_minimum_size = Vector2(200, 280)
		
		# Don't connect click signal anymore - we'll handle dragging instead
		
		card_container.add_child(card_2d)
		card_instances.append(card_2d)

func _on_scroll_changed(_value: float):
	"""Called whenever the scroll position changes"""
	_update_card_positions_from_scroll()

func _update_card_positions_from_scroll():
	"""Update card visuals based on current scroll position"""
	if card_instances.is_empty():
		return
	
	# Find the card closest to the center of the viewport
	var viewport_center_x = scroll_container.global_position.x + scroll_container.size.x / 2
	var closest_index = 0
	var closest_distance = INF
	
	for i in range(card_instances.size()):
		var card = card_instances[i]
		var card_center_x = card.global_position.x + card.size.x / 2
		var distance_to_viewport_center = abs(card_center_x - viewport_center_x)
		
		if distance_to_viewport_center < closest_distance:
			closest_distance = distance_to_viewport_center
			closest_index = i
	
	# Update current center index
	current_center_index = closest_index
	
	# Update all card visuals based on distance from center
	for i in range(card_instances.size()):
		var distance = abs(i - current_center_index)
		var card = card_instances[i]
		
		# Calculate visual properties based on distance from center
		var z_index: int
		var modulate_alpha: float
		var spacing_offset: float
		
		if distance == 0:
			# Center card - fully visible, normal spacing
			z_index = 100
			modulate_alpha = 1.0
			spacing_offset = 0.0
		elif distance <= 2:
			# Near cards - partially visible, wider spacing to show half the card
			z_index = 100 - distance
			modulate_alpha = 1.0 - (distance * 0.1)
			spacing_offset = distance * 120.0  # Wider gaps near center
		else:
			# Far cards - mostly covered, tighter spacing
			z_index = 0
			modulate_alpha = 0.5
			# Compressed spacing for far cards
			spacing_offset = 240.0 + (distance - 2) * 40.0
		
		# Apply position offset from center
		# Positive offset for cards to the right, negative for left
		var side_multiplier = 1 if i > current_center_index else -1
		if distance > 0:
			card.position.x = spacing_offset * side_multiplier
		else:
			card.position.x = 0
		
		# Apply visual effects (no scale changes)
		card.z_index = z_index
		card.modulate.a = modulate_alpha

func _on_close_pressed():
	hide()
	viewer_closed.emit()

func _input(event):
	if not visible:
		return
	
	# Handle mouse button press/release for dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start potential drag
				is_dragging = false  # Wait for movement to confirm drag
				drag_start_pos = event.position
				drag_start_scroll = scroll_container.scroll_horizontal
				get_viewport().set_input_as_handled()
			else:
				# End drag
				if is_dragging:
					is_dragging = false
					# Snap to nearest card after drag ends
					_snap_to_nearest_card()
					get_viewport().set_input_as_handled()
		
		# Handle mouse wheel scrolling
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Scroll left by one card width
				scroll_container.scroll_horizontal -= 250
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Scroll right by one card width
				scroll_container.scroll_horizontal += 250
				get_viewport().set_input_as_handled()
	
	# Handle mouse motion for dragging
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var drag_distance = event.position.distance_to(drag_start_pos)
			
			# Start dragging if we've moved enough
			if not is_dragging and drag_distance > DRAG_THRESHOLD:
				is_dragging = true
			
			if is_dragging:
				# Update scroll based on drag
				var drag_delta = drag_start_pos.x - event.position.x
				scroll_container.scroll_horizontal = drag_start_scroll + drag_delta
				get_viewport().set_input_as_handled()
	
	# Navigate with arrow keys
	if event.is_action_pressed("ui_left"):
		# Scroll left by one card width
		scroll_container.scroll_horizontal -= 250
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		# Scroll right by one card width
		scroll_container.scroll_horizontal += 250
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _snap_to_nearest_card():
	"""Smoothly snap to the nearest card after dragging"""
	if card_instances.is_empty():
		return
	
	# Calculate target scroll position to center the current card
	await get_tree().process_frame
	
	var card = card_instances[current_center_index]
	var card_center_x = card.global_position.x + card.size.x / 2
	var viewport_center_x = scroll_container.global_position.x + scroll_container.size.x / 2
	var scroll_offset = card_center_x - viewport_center_x + scroll_container.scroll_horizontal
	
	# Smoothly tween to the target scroll position
	var tween = create_tween()
	tween.tween_property(scroll_container, "scroll_horizontal", scroll_offset, 0.3)
