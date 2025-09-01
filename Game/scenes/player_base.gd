extends StaticBody3D
class_name PlayerBase

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var original_material: Material
var highlight_material: StandardMaterial3D
var is_highlighted: bool = false

# Spacing between cards
const CARD_SPACING_X: float = 0.8  # Horizontal spacing between cards

func _ready():
	# Store the original material and create highlight material
	if mesh_instance:
		original_material = mesh_instance.get_surface_override_material(0)
		if not original_material and mesh_instance.mesh:
			original_material = mesh_instance.mesh.material
		
		# Create highlight material
		highlight_material = StandardMaterial3D.new()
		highlight_material.emission = Color(0, 0, 1, 1)  # Blue highlight for player base
		highlight_material.flags_unshaded = true
		highlight_material.flags_do_not_receive_shadows = true

func getNextEmptyLocation() -> Vector3:
	"""Returns the next empty location in local coordinates, or Vector3.INF if no space"""
	# Count actual Card nodes (not by name, but by type)
	var card_count = 0
	for child in get_children():
		if child is Card:
			card_count += 1
	
	# First location is at 0,0,0, then cards go left to right
	var x_offset = card_count * CARD_SPACING_X
	
	# You can add a maximum limit here if needed
	# For now, we'll assume unlimited space
	return Vector3(x_offset, 0, 0)

func getCards() -> Array:
	"""Returns all Card nodes that are children of this PlayerBase"""
	var cards = []
	for child in get_children():
		if child is Card:
			cards.append(child)
	return cards

func highlight(enabled: bool):
	"""Enable or disable the highlight effect"""
	if not mesh_instance:
		return
		
	is_highlighted = enabled
	if enabled:
		mesh_instance.set_surface_override_material(0, highlight_material)
	else:
		mesh_instance.set_surface_override_material(0, original_material)
