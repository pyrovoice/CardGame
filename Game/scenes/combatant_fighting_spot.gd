extends StaticBody3D
class_name CombatantFightingSpot

signal onCardEnteredOrLeft

@onready var highlight_mesh: MeshInstance3D = $HighlightMesh
var is_highlighted: bool = false

func _ready():
	child_order_changed.connect(func(): 
		# Only emit signal if we're not being destroyed
		if is_inside_tree() and not is_queued_for_deletion():
			onCardEnteredOrLeft.emit()
	)
	
func setCard(c: Card, keepPos = true):
	if getCard() != null:
		print("Cannot assign %s to %s, already full"%[c.name, name])
		return
	if !c.cardData:
		print("Cannot assign %s to %s, cardData not set"%[c.name, name])
		return
	if c.get_parent() != null:
		c.reparent(self, keepPos)
	else:
		add_child(c)
	# Use global_position instead of position for correct positioning
	AnimationsManagerAL.animate_card_to_position(c, self.global_position + Vector3(0, 0.1, 0))

func getCard() -> Card:
	# Method 1: Try find_children with different parameters
	var cards = find_children("*", "Card", true, false)
	if cards.size() > 0:
		var card = cards[0]
		# Check if the found card is still valid
		if is_instance_valid(card):
			return card
	
	# Method 2: Check direct children for Card type
	for child in get_children():
		if is_instance_valid(child) and child is Card:
			return child
	
	return null

func highlight(enabled: bool):
	"""Enable or disable the highlight effect"""
	if highlight_mesh:
		is_highlighted = enabled
		highlight_mesh.visible = enabled
