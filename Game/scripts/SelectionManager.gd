extends Node
class_name SelectionManager

signal selection_completed(selection: RefCounted)
signal selection_cancelled()
signal selection_started()  # Emitted when selection UI is shown and ready

# Comprehensive selection data structure for pre-specifying all card play choices
class CardPlaySelections:
	var additional_cost_selections: Array[CardData] = []  # Cards to sacrifice/pay additional costs (deprecated - use specific arrays)
	var replace_target: CardData = null  # Target for Replace mechanism (if using Replace casting)
	var sacrifice_targets: Array[CardData] = []  # Cards to sacrifice for SacrificePermanent costs
	var spell_targets: Array[CardData] = []  # Targets for spells and abilities
	var cancelled: bool = false
	
	func _init():
		pass
	
	func set_replace_target(target: CardData):
		"""Set the card to replace (automatically enables Replace casting)"""
		replace_target = target
	
	func add_sacrifice_target(card_data: CardData):
		"""Add a card to sacrifice for additional costs"""
		sacrifice_targets.append(card_data)
	
	func add_additional_cost_selection(card_data: CardData):
		"""Add a card for additional cost payment (deprecated - use add_sacrifice_target instead)"""
		add_sacrifice_target(card_data)
	
	func add_spell_target(card_data: CardData):
		"""Add a spell target"""
		spell_targets.append(card_data)
	
	func has_selections() -> bool:
		"""Check if any selections have been made"""
		return (additional_cost_selections.size() > 0 or 
				replace_target != null or 
				sacrifice_targets.size() > 0 or
				spell_targets.size() > 0)

var selection_ui: Control
var current_selection: RefCounted = null  # PlayerSelection
var game_reference: Node = null
var casting_card: CardData = null  # Track the card being cast

func _ready():
	# Load and create the selection UI
	selection_ui = get_node("../UI/SelectionUI")  # Assign to class-level variable
	selection_ui.validate_pressed.connect(_on_validate_pressed)
	selection_ui.cancel_pressed.connect(_on_cancel_pressed)
	selection_ui.hide()

# Start a new card selection process and wait for completion
func start_selection_and_wait(requirement: Dictionary, possible_cards: Array[CardData], selection_type: String, game_ref: Node, casting_card_param: CardData = null, preselected_cards: Array[CardData] = []) -> Array[CardData]:
	print("Starting selection and waiting for completion...")
	
	# If pre-selections are provided, use them directly
	if preselected_cards.size() > 0:
		print("Using pre-selected cards: ", preselected_cards.size())
		return preselected_cards
	
	# Store casting card for potential cancellation
	casting_card = casting_card_param
	
	# Initialize the selection
	var player_selection_script = load("res://Game/scripts/PlayerSelection.gd")
	current_selection = player_selection_script.new(requirement, possible_cards, selection_type)
	game_reference = game_ref
	
	# Show UI and highlight cards
	_show_selection_ui(true)
	print("🔍 [SELECTION] UI shown, highlighting ", possible_cards.size(), " possible cards")
	for card_data in possible_cards:
		var card_node = card_data.get_card_object()
		if card_node:
			card_node.set_selectable(true)
	_update_ui()
	
	# Emit signal that selection has started
	selection_started.emit()
	
	# Wait for either completion or cancellation
	var result = await selection_completed
	
	if result:
		print("Selection completed with ", result.selected_cards.size(), " cards")
		return result.selected_cards
	else:
		print("Selection was cancelled or failed")
		return []

# Create a new empty selection set
func create_card_play_selections() -> CardPlaySelections:
	"""Factory method to create a new CardPlaySelections instance"""
	return CardPlaySelections.new()

# Handle card click during selection
func handle_card_click(card_node: Card):
	if not current_selection:
		return
	var card_data = card_node.cardData
	if not card_data:
		return
	
	if current_selection.try_select_card(card_data):
		card_node.set_selected(card_data in current_selection.selected_cards)
		_update_ui()

func _update_ui():
	if not current_selection or not selection_ui:
		return
	
	var desc = current_selection.get_requirement_description()
	desc += " (" + str(current_selection.selected_cards.size()) + "/" + str(current_selection.requirement.get("count", 1)) + ")"
	selection_ui.set_description(desc)
	selection_ui.set_validate_enabled(current_selection.is_complete)

func _show_selection_ui(visible: bool):
	if selection_ui:
		if visible:
			selection_ui.show()
		else:
			selection_ui.hide()

func _on_validate_pressed():
	if current_selection and current_selection.is_complete:
		var selection = current_selection
		_end_selection()
		selection_completed.emit(selection)

func _on_cancel_pressed():
	selection_cancelled.emit()

func _end_selection():
	if current_selection:
		for card_data in current_selection.possible_cards:
			var card_node = card_data.get_card_object()
			if card_node:
				card_node.set_selectable(false)
				card_node.set_selected(false)
	
	if casting_card:
		pass
	
	current_selection = null
	game_reference = null
	casting_card = null
	_show_selection_ui(false)

# Check if we're currently in a selection process
func is_selecting() -> bool:
	return current_selection != null

# Get the current casting card
func get_casting_card() -> CardData:
	return casting_card
