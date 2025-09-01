extends StaticBody3D
class_name PlayerBase


# Spacing between cards
const CARD_SPACING_X: float = 0.7  # Horizontal spacing between cards

func getNextEmptyLocation() -> Vector3:
	"""Returns the next empty location in local coordinates, or Vector3.INF if no space"""
	# First location is at 0,0,0, then cards go left to right
	var x_offset = find_children("Card").size() * CARD_SPACING_X
	
	# You can add a maximum limit here if needed
	# For now, we'll assume unlimited space
	return Vector3(x_offset, 0, 0)
