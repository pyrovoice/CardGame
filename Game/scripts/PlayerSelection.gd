extends RefCounted
class_name PlayerSelection

# The selection requirement data
var requirement: Dictionary = {}
var possible_cards: Array[Card] = []
var selected_cards: Array[Card] = []

# Selection state
var is_complete: bool = false
var selection_type: String = ""  # "sacrifice", "target", "choose", etc.

func _init(req: Dictionary, cards: Array[Card], type: String = ""):
	requirement = req
	possible_cards = cards
	selection_type = type
	selected_cards = []
	is_complete = false
	_check_completion()  # Check initial completion state (handles optional requirements)

# Add a card to the selection if it's valid
func try_select_card(card: Card) -> bool:
	if not card in possible_cards:
		return false
	
	# Toggle selection
	if card in selected_cards:
		selected_cards.erase(card)
	else:
		selected_cards.append(card)
	
	_check_completion()
	return true

# Check if the current selection meets the requirement
func _check_completion():
	var required_count = requirement.get("count", 1)
	var min_count = requirement.get("min_count", required_count)
	var max_count = requirement.get("max_count", required_count)
	var is_optional = requirement.get("optional", false)
	
	# If optional, selection is always complete (even with 0 cards)
	if is_optional:
		is_complete = selected_cards.size() <= max_count
		return
	
	# For exact match requirements (like "exactly 2 goblins")
	is_complete = selected_cards.size() >= min_count and selected_cards.size() <= max_count
	
	# For sacrifice requirements, must be exact
	if selection_type == "sacrifice":
		is_complete = selected_cards.size() == required_count

# Get a description of what's needed
func get_requirement_description() -> String:
	var count = requirement.get("count", 1)
	var card_filter = requirement.get("valid_card", "Any")
	
	match selection_type:
		"sacrifice":
			return "Sacrifice " + str(count) + " " + card_filter
		"target":
			return "Target " + str(count) + " " + card_filter
		_:
			return "Choose " + str(count) + " " + card_filter
