extends StaticBody3D
class_name CombatantFightingSpot

signal onCardEnteredOrLeft

@onready var highlight_mesh: MeshInstance3D = $HighlightMesh
var is_highlighted: bool = false

func getCard() -> Card:
	return find_child("Card")
	
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

func highlight(enabled: bool):
	"""Enable or disable the highlight effect"""
	if highlight_mesh:
		is_highlighted = enabled
		highlight_mesh.visible = enabled
