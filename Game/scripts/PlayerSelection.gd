extends RefCounted
class_name PlayerSelection

# The selection request that drives this selection
var request: SelectionRequest = null
var possible_cards: Array[CardData] = []
var selected_cards: Array[CardData] = []

# Selection state
var is_complete: bool = false
var selection_type: String = ""  # "sacrifice", "target", "choose", etc.

func _init(req: SelectionRequest, cards: Array[CardData], type: String = ""):
	request = req
	possible_cards = cards
	selection_type = type
	selected_cards = []
	is_complete = false
	_check_completion()  # Check initial completion state (handles optional requirements)

# Add a card to the selection if it's valid
func try_select_card(card_data: CardData) -> bool:
	if not card_data in possible_cards:
		return false
	
	# Toggle selection
	if card_data in selected_cards:
		selected_cards.erase(card_data)
	else:
		selected_cards.append(card_data)
	
	_check_completion()
	return true

# Check if the current selection meets the requirement
func _check_completion():
	var req_min = request.effective_min()
	var req_max = request.effective_max()
	
	# If optional, selection is always complete (even with 0 cards)
	if request.is_optional:
		is_complete = selected_cards.size() <= req_max
		return
	
	# For exact match requirements (like "exactly 2 goblins")
	is_complete = selected_cards.size() >= req_min and selected_cards.size() <= req_max
	
	# For sacrifice requirements, must be exact
	if selection_type == "sacrifice":
		is_complete = selected_cards.size() == request.count

# Get a description of what's needed
func get_requirement_description() -> String:
	var n = request.count
	var card_filter = request.description if not request.description.is_empty() else "Any"
	
	match selection_type:
		"sacrifice":
			return "Sacrifice " + str(n) + " " + card_filter
		"target":
			return "Target " + str(n) + " " + card_filter
		_:
			return "Choose " + str(n) + " " + card_filter
