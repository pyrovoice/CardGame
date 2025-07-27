extends Node3D
class_name GridContainer3D

@export var grid_size_x := 3
@export var grid_size_z := 2
@export var spacing := 2.0

func _ready():
	self.child_entered_tree.connect(reorganize)
	self.child_exiting_tree.connect(reorganize)

func reorganize(_n):
	for i in range(get_child_count()):
		var child = get_child(i)
		var x = i % grid_size_x
		var z = i / grid_size_x 
		child.position = Vector3(x * spacing, 0.1, z * spacing)
