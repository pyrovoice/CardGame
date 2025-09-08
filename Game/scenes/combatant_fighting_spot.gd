extends StaticBody3D
class_name CombatantFightingSpot

signal onCardEnteredOrLeft

@onready var highlight_mesh: MeshInstance3D = $HighlightMesh
var is_highlighted: bool = false
	
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
	c.position = c.position + Vector3(0, 0.1, 0)
	onCardEnteredOrLeft.emit(c)

func getCard() -> Card:
	# Method 1: Try find_children with different parameters
	var cards = find_children("*", "Card", true, false)
	if cards.size() > 0:
		print("Found card with find_children: ", cards[0].name)
		return cards[0]
	
	# Method 2: Check direct children for Card type
	for child in get_children():
		if child is Card:
			print("Found card as direct child: ", child.name)
			return child
	
	# Method 3: Debug - print all children to see what's there
	print("No Card found in CombatantFightingSpot '%s'. Children are:" % name)
	for i in range(get_child_count()):
		var child = get_child(i)
		print("  Child %d: %s (type: %s)" % [i, child.name, child.get_class()])
	
	return null

func highlight(enabled: bool):
	"""Enable or disable the highlight effect"""
	if highlight_mesh:
		is_highlighted = enabled
		highlight_mesh.visible = enabled
