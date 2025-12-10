extends Node3D
class_name Card


@onready var card_representation: MeshInstance3D = $CardRepresentation
@onready var sub_viewport: SubViewport = $CardRepresentation/SubViewport
@onready var card_2d: Card2D = $CardRepresentation/SubViewport/Card2D
@onready var card_cover: TextureRect = $CardRepresentation/SubViewport/Control/cardCover
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var highlight_mesh: MeshInstance3D = $CardRepresentation/outline
@onready var animator: CardAnimator = $CardAnimator

# Card size state
var is_small: bool = false
var is_highlighted: bool = false
var is_selectable: bool = false
var is_selected: bool = false
var is_drag_outside_hand: bool = false
var is_facedown: bool = true

var cardData: CardData
var objectID
var damage = 0
var isToken = false

static var objectUUID = -1
static func getNextID():
	objectUUID += 1
	return objectUUID

func _ready():
	# Initially show the small card, hide the full card (cards start small by default)
	# Create a unique material for this card instance
	if sub_viewport and card_representation:
		# Create a new material instance (not shared)
		var material = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		material.flags_transparent = true
		material.albedo_color = Color.WHITE
		material.albedo_texture = sub_viewport.get_texture()
		# Apply the unique material to this card
		card_representation.set_surface_override_material(0, material)
	
		

func setData(_cardData):
	if !_cardData:
		push_error("Card data is null")
		return
	cardData = _cardData
	objectID = getNextID()
	card_2d.set_card(cardData)
	# Connect to CardData signal to update display when data changes
	cardData.dirty_data.connect(_on_card_data_changed)
	updateDisplay()
	
func updateDisplay():
	if not cardData:
		print("  - ❌ ERROR: No cardData, returning early")
		return
	
	card_cover.hide()
	card_2d.hide()
	if is_facedown:
		card_cover.show()
	else:
		card_2d.show()

func describe() -> String:
	return objectID + cardData.describe()

func getPower():
	return cardData.power

func getDamage():
	return damage
	
func receiveDamage(v: int):
	damage += v
	# Emit dirty_data signal since damage affects display
	if cardData:
		cardData.dirty_data.emit()
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

func _on_card_data_changed():
	"""Called when CardData types or subtypes change"""
	if card_2d:
		card_2d.update_display()

func update_highlight_display():
	"""Update the visual highlight based on selection states only"""
	var should_show_highlight = is_selectable or is_selected or is_drag_outside_hand
	
	if highlight_mesh:
		is_highlighted = should_show_highlight
		highlight_mesh.visible = should_show_highlight
		
		if should_show_highlight:
			# Set outline color based on priority: selected > drag outside hand > selectable
			var outline_color: Color
			if is_selected:
				outline_color = Color.GREEN
			elif is_drag_outside_hand:
				outline_color = Color.RED
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

func set_selectable(selectable: bool):
	"""Mark this card as selectable during player selection"""
	is_selectable = selectable
	update_highlight_display()

func set_selected(selected: bool):
	"""Mark this card as selected during player selection"""
	is_selected = selected
	update_highlight_display()

func set_drag_outside_hand(drag_outside: bool):
	"""Mark this card as being dragged outside the hand area"""
	is_drag_outside_hand = drag_outside
	update_highlight_display()

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

func setFlip(facingUp: bool):
	is_facedown = !facingUp
	updateDisplay()

func setPositionWithoutMovingRepresentation(newPos: Vector3, isGlobal = false):
	var representationPosBefore = card_representation.global_position
	
	if isGlobal:
		global_position = newPos
	else:
		position = newPos
	
	# Don't restore position if card is being dragged by player
	if animator and animator.is_being_dragged():
		return
	
	card_representation.global_position = representationPosBefore

# Get the animator component for direct animation control
func getAnimator() -> CardAnimator:
	return animator

# Get the current animation state
func getAnimationState() -> CardAnimator.AnimationState:
	return animator.current_state

# Check if the card is currently being animated by the game
func is_being_animated() -> bool:
	return animator.current_state == CardAnimator.AnimationState.ANIMATING

# Check if the card is under player control
func is_player_manipulated() -> bool:
	return animator.current_state == CardAnimator.AnimationState.PLAYER_CONTROLLED
