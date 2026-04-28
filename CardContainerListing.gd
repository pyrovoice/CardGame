extends Control
class_name CardContainerVizualizer

@onready var scroll_container: ScrollContainer = $scrollContainer
const SCROLL_SPEED = 20
@onready var h_box_container: HBoxContainer = $scrollContainer/HBoxContainer
var card2DScene = preload("res://Shared/scenes/Card2D.tscn")

# Background mask for blocking clicks (already exists in scene as "ColorRect")
@onready var background_mask: ColorRect = $ColorRect

# Selection callback
var selection_callback: Callable = Callable()

# Track selectable cards for sorting
var selectable_card_data: Array[CardData] = []


func setContainer(cards: Array[CardData], selectable_cards: Array[CardData] = []):
	"""Setup the visualizer with a list of cards to display
	
	Args:
		cards: Array of all CardData in the container to display
		selectable_cards: Array of CardData that can be selected (highlighted and clickable)
	"""
	selectable_card_data = selectable_cards
	
	# Sort cards: selectables first, then non-selectables
	var sorted_cards = cards.duplicate()
	sorted_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		var a_selectable = a in selectable_cards
		var b_selectable = b in selectable_cards
		if a_selectable and not b_selectable:
			return true  # a comes before b
		elif not a_selectable and b_selectable:
			return false  # b comes before a
		else:
			return false  # Keep original order for same type
	)
	
	# Clear existing cards
	for c in h_box_container.get_children():
		c.queue_free()
	
	# Create Card2D views for each card
	for card_data in sorted_cards:
		var card2D: Card2D = card2DScene.instantiate()
		h_box_container.add_child(card2D)
		card2D.set_card(card_data)
		
		# Set selectable state
		var is_selectable = card_data in selectable_cards
		card2D.set_selectable(is_selectable)
		
		# Connect click signal if selectable (check callback at click time so order of
		# setContainer / set_selection_callback doesn't matter)
		if is_selectable:
			card2D.card_clicked.connect(func(_card2d): _on_card2d_clicked(card_data))

func set_selection_callback(callback: Callable):
	"""Set the callback to call when a card is clicked during selection"""
	selection_callback = callback

func _on_card2d_clicked(card_data: CardData):
	"""Handle Card2D click during selection"""
	if selection_callback.is_valid():
		selection_callback.call(card_data)

func update_card_selection_states(selected_cards: Array[CardData]):
	"""Update visual selection states of Card2D nodes"""
	for card2D in h_box_container.get_children():
		if card2D is Card2D:
			var is_selected = card2D.cardData in selected_cards
			card2D.set_selected(is_selected)
		
		
func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_on_scroll_up()
					get_viewport().set_input_as_handled()
				MOUSE_BUTTON_WHEEL_DOWN:
					_on_scroll_down()
					get_viewport().set_input_as_handled()

func _on_scroll_up():
	scroll_container.scroll_horizontal -= SCROLL_SPEED

func _on_scroll_down():
	scroll_container.scroll_horizontal += SCROLL_SPEED
