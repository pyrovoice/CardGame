extends Node3D
class_name GridContainer3D

@export var grid_size_x := 5
@export var grid_size_z := 2
@export var spacing := 0.3

func _ready():
	self.child_exiting_tree.connect(reorganize)

func reorganize(_n):
	for i in range(get_child_count()):
		var child = get_child(i)
		var x = i % grid_size_x
		var z = i / grid_size_x
		var target = Vector3(x * spacing, 0.1, z * spacing)
		if child is Card:
			child.setPositionWithoutMovingRepresentation(target)
			child.getAnimator().go_to_rest()
		else:
			child.position = target
