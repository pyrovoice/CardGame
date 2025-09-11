extends CardContainer
class_name ExtraDeck

# Set the default visibility for extra deck
func _ready():
	is_hidden_for_owner = false
	is_hidden_for_opponent = true

# Override update_size for any extra deck specific visual updates
func update_size():
	# Extra deck specific size update logic can go here
	# Could update a mesh or label showing card count
	pass
