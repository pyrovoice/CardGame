extends StaticBody3D
class_name CombatantFightingSpot

var card = null
signal onCardEnteredOrLeft

func getCard() -> Card:
	if card:
		return card
	return null
	
func setCard(c: Card, keepPos = true):
	if card:
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
	card = c
	onCardEnteredOrLeft.emit(c)
