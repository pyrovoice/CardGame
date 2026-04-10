extends Node3D
class_name OrderedZone

var xSlotSize = 50;
func organizeChildren():
	for i in range(0, self.get_children().size()):
		var currentPos = (self.get_child(i) as Card).position
		(self.get_child(i) as Card).setPositionWithoutMovingRepresentation(Vector3(xSlotSize*i, currentPos.y, currentPos.z))
	
func addAtPosition(newChild: Card, targetIndex: int = -1):
	newChild.reparent(self)
	if targetIndex > 0:
		move_child(newChild, targetIndex)
	await get_tree().process_frame
	organizeChildren()
	
