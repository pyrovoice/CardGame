extends Node3D
class_name CardHand

func _ready():
	# Signal when a child is added or removed - reorganize cards
	child_exiting_tree.connect(func(_c): call_deferred("arrange_cards_fan")) 

func arrange_card_fan(card: Card):
	return arrange_cards_fan([card])
	
func arrange_cards_fan(addedCards: Array[Card] = []):
	# Add new cards to hand if any were provided
	for c in addedCards:
		GameUtility.reparentWithoutMoving(c, self)
	# Get current cards and count after any reparenting
	var cards = get_children()
	var count = cards.size()
	if count == 0:
		return
	
	var spacing = 0.60       # Horizontal space between cards
	
	# Calculate starting offset to center the cards
	var total_width = spacing * (count - 1)
	var start_x = -total_width / 2
	
	for i in range(count):
		var card: Card = cards[i]
		if not card is Card:
			continue
		
		var target_x = start_x + spacing * i
		
		if addedCards != null && addedCards.find(card) != -1:
			# For newly added cards, set logical position without moving representation
			card.setPositionWithoutMovingRepresentation(Vector3(target_x, 0, 0))
			card.getAnimator().go_to_rest()
		else:
			# For existing cards, slide to new X position while preserving visual effects
			var current_pos = card.position
			var new_pos = Vector3(target_x, current_pos.y, current_pos.z)
			card.getAnimator().slide_to_position(new_pos)
