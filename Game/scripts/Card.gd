extends Node3D
class_name Card

@onready var card_representation: Node3D = $CardRepresentation
@onready var card_2d_display: MeshInstance3D = $CardRepresentation/Card2DDisplay
@onready var sub_viewport: SubViewport = $CardRepresentation/Card2DDisplay/SubViewport
@onready var card_2d_full: Card2D = $CardRepresentation/Card2DDisplay/SubViewport/Card2D
@onready var card_2d_small: Card2D_Small = $CardRepresentation/Card2DDisplay/SubViewport/Card2D_Small
@onready var collision_shape_3d: CollisionShape3D = $CardRepresentation/CollisionShape3D
@onready var highlight_mesh: MeshInstance3D = $CardRepresentation/Card2DDisplay/HighlightMesh

# Card size state
var is_small: bool
var is_highlighted: bool = false

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
	(card_2d_display.mesh as QuadMesh).size.y = 0.55
	(collision_shape_3d.shape as BoxShape3D).size.y = 0.55
	sub_viewport.size = Vector2i(150, 150)
	scale = Vector3(1, 1, 1)
	updateDisplay()

func makeBig():
	if not is_small:
		return
	is_small = false
	
	# Reset SubViewport size for full card
	(card_2d_display.mesh as QuadMesh).size.y = 0.89
	(collision_shape_3d.shape as BoxShape3D).size.y = 0.89
	sub_viewport.size = Vector2i(198, 267)
	scale = Vector3(1.5, 1.5, 1.5)
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

func highlight(enabled: bool):
	"""Enable or disable the highlight effect"""
	if highlight_mesh :
		is_highlighted = enabled
		highlight_mesh.visible = enabled

func set_glow_effect(enabled: bool, glow_color: Color = Color.CYAN, glow_intensity: float = 1.0):
	"""Enable or disable glow effect on the card"""
	if not card_2d_display:
		return
	
	var material = card_2d_display.get_surface_override_material(0)
	if not material:
		# Create a new material if none exists
		material = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		material.flags_transparent = true
		material.albedo_color = Color.WHITE
		material.albedo_texture = sub_viewport.get_texture()
		card_2d_display.set_surface_override_material(0, material)
	
	if enabled:
		# Enable emission for glow effect
		material.emission_enabled = true
		material.emission = glow_color
		material.emission_energy = glow_intensity
	else:
		# Disable emission
		material.emission_enabled = false
		material.emission = Color.BLACK
		material.emission_energy = 0.0
