extends StaticBody3D
class_name PlayerBase

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var original_material: Material
var highlight_material: StandardMaterial3D
var is_highlighted: bool = false

# Spacing between cards
const CARD_SPACING_X: float = 0.7  # Horizontal spacing between cards

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
	
	# Connect signals to reorganize cards when they are added or removed
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)

func _on_child_entered_tree(node: Node):
	"""Called when a child node is added to the PlayerBase"""
	if node is Card:
		# Use call_deferred to ensure the card is fully added before organizing
		call_deferred("organize")

func _on_child_exiting_tree(node: Node):
	"""Called when a child node is removed from the PlayerBase"""
	if node is Card:
		# Use call_deferred to reorganize after the card is removed
		call_deferred("organize")

func organize():
	"""Reorganize all cards in the PlayerBase to be placed next to each other"""
	var cards = getCards()
	
	for i in range(cards.size()):
		var card = cards[i]
		var target_position = Vector3(i * CARD_SPACING_X, 0, 0)
		
		# Use the card's move_to_position method for smooth movement
		if card.has_method("move_to_position"):
			card.move_to_position(target_position, 5.0)  # 5.0 speed for smooth movement
		else:
			# Fallback to direct position setting if method doesn't exist
			card.position = target_position

func getNextEmptyLocation() -> Vector3:
	"""Returns the next empty location in local coordinates, or Vector3.INF if no space"""
	# Count actual Card nodes (not by name, but by type)
	var card_count = 0
	for child in get_children():
		if child is Card:
			card_count += 1
	
	# Cards are organized with CARD_SPACING_X between them, starting at x=0
	var x_offset = card_count * CARD_SPACING_X
	
	# You can add a maximum limit here if needed
	# For now, we'll assume unlimited space
	return Vector3(x_offset, 0, 0)

func getCards() -> Array[Card]:
	"""Returns all Card nodes that are children of this PlayerBase"""
	var cards: Array[Card] = []
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
