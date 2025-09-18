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

# Check if a specific card meets the requirement filter
static func card_matches_filter(card: Card, filter: String) -> bool:
	if filter == "Any":
		return true
	
	# Parse filter like "Card.YouCtrl+Goblin"
	var conditions = filter.split("+")
	
	for condition in conditions:
		condition = condition.strip_edges()
		
		if condition == "Card.YouCtrl":
			# Check if card is controlled by current player
			if not card.controlled_by_current_player():
				return false
		elif condition == "Goblin":
			# Check if card has Goblin subtype
			if not card.cardData.subtypes.has("Goblin"):
				return false
		elif condition == "Creature":
			# Check if card is a creature
			if not card.cardData.hasType(CardData.CardType.CREATURE):
				return false
		# Add more filter conditions as needed
	
	return true
