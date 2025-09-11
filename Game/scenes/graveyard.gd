extends CardContainer
class_name Graveyard

# Set the default visibility for graveyard
func _ready():
	is_hidden_for_owner = false
	is_hidden_for_opponent = false  # Graveyard is usually visible to both players

# Override update_size for any graveyard specific visual updates
func update_size():
	# Graveyard specific size update logic can go here
	# Could show the number of cards in graveyard or stack height
	pass
