extends Node3D
class_name Card

@onready var card_representation: Node3D = $CardRepresentation
@onready var card_2d_display: MeshInstance3D = $CardRepresentation/Card2DDisplay
@onready var highlight_mesh: MeshInstance3D = $CardRepresentation/HighlightMesh
@onready var sub_viewport: SubViewport = $CardRepresentation/Card2DDisplay/SubViewport
@onready var card_2d_full: Card2D = $CardRepresentation/Card2DDisplay/SubViewport/Card2D
@onready var card_2d_small: Card2D_Small = $CardRepresentation/Card2DDisplay/SubViewport/Card2D_Small

# Card size state
var is_small: bool = false
var is_highlighted: bool = false

enum CardControlState{
	FREE,
	MOVED_BY_PLAYER,
	MOVED_BY_GAME
}

var cardData: CardData
var objectID
var cardControlState: CardControlState = CardControlState.FREE
var angleInHand: Vector3 = Vector3.ZERO
var damage = 0
const popUpVal = 1.0

static var objectUUID = -1
static func getNextID():
	objectUUID += 1
	return objectUUID

func _ready():
	# Initially hide the small card, show the full card
	if card_2d_small:
		card_2d_small.hide()
	if card_2d_full:
		card_2d_full.show()
	
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

func _process(delta):
	if cardControlState == CardControlState.FREE:
		card_representation.position = card_representation.position.lerp(Vector3.ZERO, 0.2)
		card_representation.rotation_degrees.x = lerp(card_representation.rotation_degrees.x, angleInHand.x, 0.2)
	
	if cardControlState == CardControlState.MOVED_BY_PLAYER:
		cardControlState = CardControlState.FREE
	
func setData(_cardData):
	if !_cardData:
		push_error("Card data is null")
		return
	cardData = _cardData
	objectID = getNextID()
	updateDisplay()
	
func updateDisplay():
	print("🔍 updateDisplay() called for card: ", cardData.cardName if cardData else "NO CARD DATA")
	print("  - is_small: ", is_small)
	
	if not cardData:
		print("  - ❌ ERROR: No cardData, returning early")
		return
	
	if is_small:
		if card_2d_full:
			card_2d_full.hide()
		else:
			print("    - ❌ ERROR: card_2d_full is null!")
			
		if card_2d_small:
			card_2d_small.show()
			card_2d_small.set_card_data(cardData)
		else:
			print("    - ❌ ERROR: card_2d_small is null!")
	else:
		if card_2d_small:
			card_2d_small.hide()
		else:
			print("    - ❌ ERROR: card_2d_small is null!")
			
		if card_2d_full:
			card_2d_full.show()
			card_2d_full.set_card_data(cardData)
		else:
			print("    - ❌ ERROR: card_2d_full is null!")

func popUp():
	if cardControlState == CardControlState.MOVED_BY_GAME:
		return
	var pos := card_representation.position
	pos.y = lerp(pos.y, popUpVal + (position.y*2), 0.4)
	pos.z = lerp(pos.z, 0.2 + (position.z), 0.4)
	card_representation.position = pos
	card_representation.rotation_degrees.x = 90

func dragged(pos: Vector3):
	if cardControlState == CardControlState.MOVED_BY_GAME:
		return
	cardControlState = CardControlState.MOVED_BY_PLAYER
	card_representation.global_position = card_representation.global_position.lerp(pos, 0.4)
	card_representation.position.z = 0.1

func animatePlayedTo(targetPos: Vector3):
	cardControlState = CardControlState.MOVED_BY_GAME
	var cardRepresentationPosBefore = card_representation.global_position
	global_position = targetPos
	card_representation.global_position = cardRepresentationPosBefore
	makeSmall()
	while card_representation.position.distance_to(Vector3.ZERO) > 0.1:
		await move_to_position(Vector3.ZERO, 10)
	card_representation.rotation_degrees.x = 90
	return true
	
func move_to_position(target: Vector3, speed: float) -> void:
	var posBefore = card_representation.global_position
	card_representation.position = card_representation.position.lerp(target, speed * get_process_delta_time())
	var posafter = card_representation.global_position
	await get_tree().process_frame
	
func describe() -> String:
	return objectID + cardData.describe()

func setRotation(angle_deg: Vector3, rotationValue):
		card_representation.rotation_degrees = angle_deg
		card_representation.rotate_z(rotationValue)
		angleInHand = card_representation.rotation_degrees

func makeSmall():
	print("🔍 makeSmall() called for card: ", cardData.cardName if cardData else "NO CARD DATA")
	print("  - Current is_small state: ", is_small)
	
	if is_small:
		print("  - Card is already small, returning early")
		return
		
	is_small = true
	print("  - Setting is_small = true")
	
	# Check if UI elements exist before trying to manipulate them
	if not card_2d_full:
		print("  - ❌ ERROR: card_2d_full is null!")
		return
	if not card_2d_small:
		print("  - ❌ ERROR: card_2d_small is null!")
		return
	if not sub_viewport:
		print("  - ❌ ERROR: sub_viewport is null!")
		return
	if not card_2d_display:
		print("  - ❌ ERROR: card_2d_display is null!")
		return
	
	print("  - All UI elements found, proceeding with size change")
	
	# Simply hide full card and show small card
	card_2d_full.hide()
	card_2d_small.show()
	print("  - Switched to small card display")
	
	# Adjust SubViewport size to match small card size
	print("  - Old SubViewport size: ", sub_viewport.size)
	sub_viewport.size = Vector2i(120, 100)
	print("  - New SubViewport size: ", sub_viewport.size)
	
	# Force SubViewport to update using different methods
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	print("  - Set SubViewport to UPDATE_ONCE")
	
	# Also try to force an immediate render
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	call_deferred("_finish_make_small_setup")

func _finish_make_small_setup():
	print("  - _finish_make_small_setup() called")
	
	# Check SubViewport texture
	var viewport_texture = sub_viewport.get_texture()
	print("  - SubViewport texture: ", viewport_texture)
	if viewport_texture:
		print("    - Texture size: ", viewport_texture.get_size())
	
	# Scale the 3D display accordingly
	if card_2d_display:
		print("  - Old card_2d_display scale: ", card_2d_display.scale)
		card_2d_display.scale = Vector3(1, 0.60, 1.0)  # Roughly half the length
		print("  - New card_2d_display scale: ", card_2d_display.scale)
		
		# Check if the material has the updated texture
		var material = card_2d_display.get_surface_override_material(0)
		if material:
			print("  - Material found: ", material)
			print("  - Material texture: ", material.albedo_texture)
			if material.albedo_texture:
				print("    - Material texture size: ", material.albedo_texture.get_size())
			
			# Try to refresh the material texture
			material.albedo_texture = sub_viewport.get_texture()
			print("  - Updated material texture reference")
		else:
			print("  - ❌ WARNING: No material found on card_2d_display")
	
	# Update display to ensure small card has correct data
	if cardData:
		print("  - Calling updateDisplay() to refresh card data")
		updateDisplay()
	else:
		print("  - ❌ WARNING: No cardData available to update display")
	
	print("  - makeSmall() completed")

func makeBig():
	if not is_small:
		return
		
	is_small = false
	
	# Simply hide small card and show full card
	card_2d_small.hide()
	card_2d_full.show()
	
	# Reset SubViewport size for full card
	sub_viewport.size = Vector2i(150, 200)
	
	# Force SubViewport to update
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Reset the 3D display scale
	if card_2d_display:
		card_2d_display.scale = Vector3(1.0, 1.0, 1.0)

func getPower():
	return cardData.power

func getDamage():
	return damage
	
func receiveDamage(v: int):
	damage += v
	updateDisplay()

func highlight(enabled: bool):
	"""Enable or disable the highlight effect"""
	if highlight_mesh:
		is_highlighted = enabled
		highlight_mesh.visible = enabled
