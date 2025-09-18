extends Node3D
class_name Card

@onready var card_representation: Node3D = $CardRepresentation
@onready var card_2d_display: MeshInstance3D = $CardRepresentation/Card2DDisplay
@onready var sub_viewport: SubViewport = $CardRepresentation/Card2DDisplay/SubViewport
@onready var card_2d_full: Card2D = $CardRepresentation/Card2DDisplay/SubViewport/Card2D
@onready var card_2d_small: Card2D_Small = $CardRepresentation/Card2DDisplay/SubViewport/Card2D_Small
@onready var collision_shape_3d: CollisionShape3D = $CardRepresentation/CollisionShape3D
@onready var highlight_mesh: MeshInstance3D = $CardRepresentation/Card2DDisplay/outline

# Card size state
var is_small: bool
var is_highlighted: bool = false
var is_selectable: bool = false
var is_selected: bool = false

enum CardControlState{
	FREE,
	MOVED_BY_PLAYER,
	MOVED_BY_GAME
}

var cardData: CardData
var objectID
var cardControlState: CardControlState = CardControlState.FREE
var damage = 0
var isToken = false

static var objectUUID = -1
static func getNextID():
	objectUUID += 1
	return objectUUID

func _ready():
	# Initially show the small card, hide the full card (cards start small by default)
	# Create a unique material for this card instance
	if sub_viewport and card_2d_display:
		# Create a new material instance (not shared)
		var material = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		material.flags_transparent = true
		material.albedo_color = Color.WHITE
		material.albedo_texture = sub_viewport.get_texture()
		
		# Apply the unique material to this card
		card_2d_display.set_surface_override_material(0, material)
	makeSmall()

func setData(_cardData):
	if !_cardData:
		push_error("Card data is null")
		return
	cardData = _cardData
	objectID = getNextID()
	updateDisplay()
	
func updateDisplay():
	if not cardData:
		print("  - ❌ ERROR: No cardData, returning early")
		return
	
	if is_small:
		if card_2d_full:
			card_2d_full.hide()
			
		if card_2d_small:
			card_2d_small.show()
			card_2d_small.set_card(self)
	else:
		if card_2d_small:
			card_2d_small.hide()
			
		if card_2d_full:
			card_2d_full.show()
			card_2d_full.set_card(self)

func popUp():
	"""Delegate popup animation to AnimationsManager"""
	AnimationsManagerAL.animate_card_popup(self)

func dragged(pos: Vector3):
	"""Delegate dragged animation to AnimationsManager"""
	AnimationsManagerAL.animate_card_dragged(self, pos)
	
func animatePlayedTo(targetPos: Vector3):
	"""Delegate card movement animation to AnimationsManager"""
	return await AnimationsManagerAL.animate_card_to_position(self, targetPos)
	
func describe() -> String:
	return objectID + cardData.describe()

func makeSmall():
	if is_small:
		return
	is_small = true
	card_2d_full.hide()
	card_2d_small.show()
	# Adjust SubViewport size to match small card size
	(card_2d_display.mesh as PlaneMesh).size.y = 0.55
	(collision_shape_3d.shape as BoxShape3D).size.y = 0.55
	sub_viewport.size = Vector2i(150, 150)
	scale = Vector3(1, 1, 1)
	
	# Scale highlight mesh to match small card size
	if highlight_mesh:
		highlight_mesh.scale = Vector3(1.05, 1, 0.65)  # Adjust Y scale to match card ratio
	
	updateDisplay()

func makeBig():
	if not is_small:
		return
	is_small = false
	
	# Reset SubViewport size for full card
	(card_2d_display.mesh as PlaneMesh).size.y = 0.89
	(collision_shape_3d.shape as BoxShape3D).size.y = 0.89
	sub_viewport.size = Vector2i(198, 267)
	scale = Vector3(1.5, 1.5, 1.5)
	
	# Reset highlight mesh to match big card size
	if highlight_mesh:
		highlight_mesh.scale = Vector3(1.05, 1.05, 1.0)  # Back to normal scale
	
	updateDisplay()

func getPower():
	return cardData.power

func getDamage():
	return damage
	
func receiveDamage(v: int):
	damage += v
	updateDisplay()
	
	# Find the Game node and resolve state-based actions
	var game_node = _find_game_node()
	if game_node and game_node.has_method("resolveStateBasedAction"):
		game_node.resolveStateBasedAction()

func _find_game_node() -> Node:
	"""Find the Game node by traversing up the tree"""
	var current = self
	while current:
		if current is Game:
			return current
		current = current.get_parent()
	return null

func highlight(_enabled: bool):
	"""Enable or disable the hover highlight effect - DISABLED: using different hover system"""
	# No longer using outline highlights for hover
	pass

func update_highlight_display():
	"""Update the visual highlight based on selection states only"""
	var should_show_highlight = is_selectable or is_selected
	
	if highlight_mesh:
		is_highlighted = should_show_highlight
		highlight_mesh.visible = should_show_highlight
		
		if should_show_highlight:
			# Set outline color based on priority: selected > selectable
			var outline_color: Color
			if is_selected:
				outline_color = Color.GREEN
			elif is_selectable:
				outline_color = Color.BLUE
			else:
				outline_color = Color.WHITE
			
			set_outline_color(outline_color)
	else:
		print("[Card ", objectID, "] ERROR: highlight_mesh is null!")

func set_outline_color(color: Color):
	"""Set the color of the outline mesh"""
	if not highlight_mesh:
		return
	
	# Get or create material for the outline
	var material = highlight_mesh.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		material.flags_transparent = true
		material.no_depth_test = true  # Make sure outline shows on top
		highlight_mesh.set_surface_override_material(0, material)
	
	# Set the outline color
	material.albedo_color = color
	print("[Card ", objectID, "] Set outline color to: ", color)

func set_selectable(selectable: bool):
	"""Mark this card as selectable during player selection"""
	is_selectable = selectable
	update_highlight_display()

func set_selected(selected: bool):
	"""Mark this card as selected during player selection"""
	is_selected = selected
	update_highlight_display()

func controlled_by_current_player() -> bool:
	"""Check if this card is controlled by the current player"""
	# For now, assume all cards are controlled by the player
	# This should be updated when multiplayer is implemented
	return true

# Update highlight mesh to match card dimensions
func update_highlight_mesh_size(card_height: float):
	if not highlight_mesh or not highlight_mesh.mesh:
		return
	
	# Get the current mesh
	var mesh = highlight_mesh.mesh as ArrayMesh
	if not mesh:
		return
	
	# Calculate scale factor based on card height
	var scale_factor = card_height / 0.89  # 0.89 is the default big card height
	
	# Option 1: Simple scaling (recommended)
	highlight_mesh.scale = Vector3(1.0, scale_factor, 1.0)
	
	# Option 2: Rebuild the mesh (uncomment if you need precise control)
	# rebuild_highlight_mesh(card_height)

# Advanced: Rebuild the highlight mesh for precise outline control
func rebuild_highlight_mesh(card_height: float):
	if not highlight_mesh:
		return
	
	# Create new outline mesh with custom dimensions
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Define outline vertices based on card dimensions
	var card_width = 0.6  # Assuming standard card width
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Create outline quad vertices
	vertices.push_back(Vector3(-card_width/2, -card_height/2, 0.001))  # Bottom left
	vertices.push_back(Vector3(card_width/2, -card_height/2, 0.001))   # Bottom right  
	vertices.push_back(Vector3(card_width/2, card_height/2, 0.001))    # Top right
	vertices.push_back(Vector3(-card_width/2, card_height/2, 0.001))   # Top left
	
	# UV coordinates
	uvs.push_back(Vector2(0, 0))
	uvs.push_back(Vector2(1, 0))
	uvs.push_back(Vector2(1, 1))
	uvs.push_back(Vector2(0, 1))
	
	# Indices for two triangles
	indices.push_back(0)
	indices.push_back(1)
	indices.push_back(2)
	indices.push_back(0)
	indices.push_back(2)
	indices.push_back(3)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	highlight_mesh.mesh = array_mesh
