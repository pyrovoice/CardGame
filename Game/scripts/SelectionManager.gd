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

var current_selection: RefCounted = null  # PlayerSelection
var game_reference: Node = null
var casting_card: CardData = null  # Track the card being cast

# References to shared UI buttons
var main_action_button: Button = null
var secondary_action_button: Button = null

# Reference to container visualizer
var container_visualizer: CardContainerVizualizer = null

# Store original button text to restore later
var original_main_button_text: String = ""
var original_secondary_button_text: String = ""

# Track if using visualizer for current selection
var using_visualizer: bool = false

func _ready():
	# References to buttons are set by game.gd via setup_buttons()
	pass

func setup_buttons(main_btn: Button, secondary_btn: Button, visualizer: CardContainerVizualizer = null):
	"""Setup references to shared UI buttons and visualizer - called by game.gd"""
	main_action_button = main_btn
	secondary_action_button = secondary_btn
	container_visualizer = visualizer
	
	# Store original button text
	if main_action_button:
		original_main_button_text = main_action_button.text
	if secondary_action_button:
		original_secondary_button_text = secondary_action_button.text
		# Hide secondary button by default
		secondary_action_button.visible = false

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
	
	# Check if all possible cards are in the same container zone
	var container_zone = _get_container_zone_if_all_same(possible_cards)
	
	if container_zone != null and container_visualizer:
		# Use visualizer for container selection
		using_visualizer = true
		print("🗂️ [SELECTION] Using container visualizer for zone: ", GameZone.e.keys()[container_zone])
		
		# Get all cards in the container zone from GameData
		var game = game_reference as Game
		if game and game.game_data:
			var all_cards_in_zone = game.game_data.get_cards_in_zone(container_zone)
			
			# Setup visualizer with all cards and selectable cards
			container_visualizer.setContainer(all_cards_in_zone, possible_cards)
			container_visualizer.set_selection_callback(_on_visualizer_card_clicked)
			container_visualizer.show()
	else:
		# Use 3D world highlighting for non-container selections
		using_visualizer = false
		print("🔍 [SELECTION] Highlighting ", possible_cards.size(), " possible cards in 3D world")
		var hm := _get_highlight_manager()
		if hm:
			hm.clear_all()
			for card_data in possible_cards:
				var card_node = card_data.get_card_object()
				if card_node:
					hm.set_card_highlight(card_node, HighlightManager.CardHighlightState.CASTABLE)
	
	# Update button UI for selection mode
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

func _is_container_zone(zone: GameZone.e) -> bool:
	"""Check if a zone is a container zone (deck, graveyard, extra deck)"""
	return zone == GameZone.e.DECK_PLAYER or \
		zone == GameZone.e.DECK_OPPONENT or \
		zone == GameZone.e.GRAVEYARD_PLAYER or \
		zone == GameZone.e.GRAVEYARD_OPPONENT or \
		zone == GameZone.e.EXTRA_DECK_PLAYER

func _get_container_zone_if_all_same(cards: Array[CardData]) -> Variant:
	"""Check if all cards are in the same container zone. Returns zone enum or null."""
	if cards.is_empty():
		return null
	
	var first_zone = cards[0].current_zone
	if not _is_container_zone(first_zone):
		return null
	
	# Check if all cards are in the same zone
	for card_data in cards:
		if card_data.current_zone != first_zone:
			return null  # Cards are in different zones
	
	return first_zone

func _on_visualizer_card_clicked(card_data: CardData):
	"""Handle card click from visualizer during selection"""
	if not current_selection:
		return
	
	if current_selection.try_select_card(card_data):
		_update_ui()

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
		var hm := _get_highlight_manager()
		if hm and not using_visualizer:
			var state = HighlightManager.CardHighlightState.SELECTED if card_data in current_selection.selected_cards else HighlightManager.CardHighlightState.CASTABLE
			hm.set_card_highlight(card_node, state)
		_update_ui()

func _update_ui():
	if not current_selection:
		return
	
	# Build description text with count
	var desc = current_selection.get_requirement_description()
	desc += " (" + str(current_selection.selected_cards.size()) + "/" + str(current_selection.requirement.get("count", 1)) + ")"
	
	# Update main button text and enable state
	if main_action_button:
		main_action_button.text = desc
		main_action_button.disabled = not current_selection.is_complete
	
	# Show secondary button for cancellation
	if secondary_action_button:
		secondary_action_button.text = "Cancel"
		secondary_action_button.visible = true
		secondary_action_button.disabled = false
	
	# Update visualizer selection states if using it
	if using_visualizer and container_visualizer:
		container_visualizer.update_card_selection_states(current_selection.selected_cards)

func validate_selection():
	"""Public method for controller to validate selection"""
	if current_selection and current_selection.is_complete:
		var selection = current_selection
		_end_selection()
		selection_completed.emit(selection)

func cancel_selection():
	"""Public method for controller to cancel selection"""
	_end_selection()
	selection_cancelled.emit()

func _end_selection():
	# Restore card states
	if current_selection:
		if using_visualizer:
			# Clear visualizer selection states
			if container_visualizer:
				container_visualizer.update_card_selection_states([])
				container_visualizer.hide()
		# Always refresh highlights - visualizer selections leave hand cards in a stale state
		var hm := _get_highlight_manager()
		if hm:
			hm.onHighlight()
	
	# Restore button states
	if main_action_button:
		main_action_button.text = original_main_button_text
		main_action_button.disabled = false
	
	if secondary_action_button:
		secondary_action_button.visible = false
		secondary_action_button.text = original_secondary_button_text
	
	# Clear selection state
	if casting_card:
		pass
	
	current_selection = null
	game_reference = null
	casting_card = null
	using_visualizer = false

# Helper to get the HighlightManager from game_reference
func _get_highlight_manager() -> HighlightManager:
	var game := game_reference as Game
	if game:
		return game.highlightManager
	return null

# Check if we're currently in a selection process
func is_selecting() -> bool:
	return current_selection != null

# Get the current casting card
func get_casting_card() -> CardData:
	return casting_card
