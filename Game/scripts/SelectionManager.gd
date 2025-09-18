extends Node
class_name SelectionManager

signal selection_completed(selection: RefCounted)
signal selection_cancelled()

var selection_ui: Control
var current_selection: RefCounted = null  # PlayerSelection
var game_reference: Node = null

func _ready():
	# Load and create the selection UI
	selection_ui = get_node("../UI/SelectionUI")  # Assign to class-level variable
	selection_ui.validate_pressed.connect(_on_validate_pressed)
	selection_ui.cancel_pressed.connect(_on_cancel_pressed)
	selection_ui.hide()

# Start a new card selection process and wait for completion
func start_selection_and_wait(requirement: Dictionary, possible_cards: Array[Card], selection_type: String, game_ref: Node) -> Array[Card]:
	"""Start selection process and await its completion, returning selected cards"""
	print("Starting selection and waiting for completion...")
	
	# Start the selection process
	start_selection(requirement, possible_cards, selection_type, game_ref)
	
	# Wait for either completion or cancellation
	var result = await selection_completed
	
	if result and result.selected_cards:
		print("Selection completed with ", result.selected_cards.size(), " cards")
		return result.selected_cards
	else:
		print("Selection was cancelled or failed")
		return []

# Start a new card selection process
func start_selection(requirement: Dictionary, possible_cards: Array[Card], selection_type: String, game_ref: Node):
	var player_selection_script = load("res://Game/scripts/PlayerSelection.gd")
	current_selection = player_selection_script.new(requirement, possible_cards, selection_type)
	game_reference = game_ref
	
	# Show UI
	_show_selection_ui(true)
	
	# Highlight possible cards
	for card in possible_cards:
		card.set_selectable(true)
	
	# Update UI
	_update_ui()

# Handle card click during selection
func handle_card_click(card: Card):
	if not current_selection:
		return
	
	if current_selection.try_select_card(card):
		# Update card visual state
		card.set_selected(card in current_selection.selected_cards)
		
		# Update UI
		_update_ui()

# Update the selection UI
func _update_ui():
	if not current_selection or not selection_ui:
		return
	
	var desc = current_selection.get_requirement_description()
	desc += " (" + str(current_selection.selected_cards.size()) + "/" + str(current_selection.requirement.get("count", 1)) + ")"
	selection_ui.set_description(desc)
	selection_ui.set_validate_enabled(current_selection.is_complete)

# Show/hide selection UI
func _show_selection_ui(visible: bool):
	if selection_ui:
		if visible:
			selection_ui.show()
		else:
			selection_ui.hide()

# Handle validate button press
func _on_validate_pressed():
	if current_selection and current_selection.is_complete:
		var selection = current_selection
		_end_selection()
		selection_completed.emit(selection)

# Handle cancel button press
func _on_cancel_pressed():
	_end_selection()
	selection_cancelled.emit()

# Clean up current selection
func _end_selection():
	if current_selection:
		# Clear all card highlights and selections
		for card in current_selection.possible_cards:
			card.set_selectable(false)
			card.set_selected(false)
	
	current_selection = null
	game_reference = null
	_show_selection_ui(false)

# Check if we're currently in a selection process
func is_selecting() -> bool:
	return current_selection != null
