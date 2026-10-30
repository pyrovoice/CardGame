extends Node3D
class_name GridContainer3D

@export var grid_size_x := 5
@export var grid_size_z := 2
@export var spacing := 0.3

func _ready():
	self.child_exiting_tree.connect(_on_child_exiting)

func _on_child_exiting(node):
	if node is Card:
		node.scale.x = 1  # Reset any Giant footprint stretch before it leaves this grid
	reorganize(node)

func reorganize(_n):
	var slot_cursor := 0
	for i in range(get_child_count()):
		var child = get_child(i)
		var width := 1
		if child is Card and child.cardData:
			width = child.cardData.get_combat_size()
		var x = (slot_cursor + (width - 1) / 2.0) * spacing
		var z = (slot_cursor / grid_size_x) * spacing
		var target = Vector3(x, 0.1, z)
		if child is Card:
			child.setPositionWithoutMovingRepresentation(target)
			child.getAnimator().go_to_rest()
			child.scale.x = width  # Giant renders twice as wide, same depth
		else:
			child.position = target
		slot_cursor += width
