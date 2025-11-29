extends Node3D
class_name CardHand

func _ready():
	# Signal when a child is removed from this node - reorganize remaining cards
	child_exiting_tree.connect(func(_node): 
		# Use call_deferred to ensure the child is fully removed before reorganizing
		call_deferred("_deferred_arrange_cards"))

func addCard(card: Card):
	arrange_cards_fan([card])

func addCards(cards: Array[Card]):
	"""Add multiple cards to hand at once"""
	arrange_cards_fan(cards)

func _deferred_arrange_cards():
	"""Called on next frame to reorganize cards after one is removed"""
	arrange_cards_fan([])
	
func arrange_cards_fan(addedCards: Array[Card]):
	# Add new cards to hand if any were provided
	if addedCards != null && addedCards.size() > 0:
		for c in addedCards:
			c.reparent(self)
	
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
		
		if addedCards != null && addedCards.find(card) != -1:
			# For newly added cards, set logical position without moving representation
			card.setPositionWithoutMovingRepresentation(Vector3(start_x + spacing * i, 0, 0))
		else:
			# For existing cards, slide to new X position while preserving visual effects
			var new_x = start_x + spacing * i
			var current_pos = card.position
			card.getAnimator().slide_to_position(Vector3(new_x, current_pos.y, current_pos.z))
