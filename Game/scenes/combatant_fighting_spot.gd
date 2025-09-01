extends StaticBody3D
class_name CombatantFightingSpot

signal onCardEnteredOrLeft

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
