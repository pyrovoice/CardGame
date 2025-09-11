extends StaticBody3D
class_name CardContainer

# Common properties for all card containers
var cards: Array[CardData] = []
var is_hidden_for_owner = false
var is_hidden_for_opponent = true

# Add a card to this container
func add_card(card_data: CardData):
	cards.append(card_data)
	update_size()

# Remove a card from this container
func remove_card(card_data: CardData) -> bool:
	var index = cards.find(card_data)
	if index != -1:
		cards.remove_at(index)
		update_size()
		return true
	return false

# Get the number of cards in this container
func get_card_count() -> int:
	return cards.size()

# Check if the container is empty
func is_empty() -> bool:
	return cards.is_empty()

# Clear all cards from this container
func clear_cards():
	cards.clear()
	update_size()

# Get all cards in this container
func get_cards() -> Array[CardData]:
	return cards.duplicate()

# Virtual method to update visual representation - override in child classes
func update_size():
	# Default implementation - child classes should override this
	pass

# Check if this container is hidden for a specific player
func is_hidden_for_player(is_owner: bool) -> bool:
	if is_owner:
		return is_hidden_for_owner
	else:
		return is_hidden_for_opponent
