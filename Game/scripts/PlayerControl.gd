extends Node3D
class_name PlayerControl

# Reference to the CardPopupManager in the UI
@onready var card_popup_manager: CardPopupManager = $"../UI/CardPopupManager"

@onready var player_hand: Node3D = $"../Camera3D/PlayerHand"
@onready var mouse_intercept_plane: StaticBody3D = $"../Camera3D/mouseInterceptPlane"
@onready var camera: Camera3D = $"../Camera3D"

signal onCardHover(card: Card, zone: GameZone.e)
signal rightClick(card: Card)
signal leftClick(objectUnderMouse: Node3D)
signal cardDragStarted(card: Card)
signal cardDragPositionChanged(card: Card, is_outside_hand: bool, pos: Vector3)
signal cardDragEnded(card: Card, is_outside_hand: bool, targetLocation: Node3D)

const HAND_ZONE_CUTTOFF = 530

# Dragging offset constant
const DRAG_OFFSET_X = 150  # Pixels to offset dragged card to the right

# Popup positioning constants (same as CardAlbum)
const POPUP_LEFT_MARGIN = 5
const ENLARGED_CARD_HEIGHT = 600

func _ready():
	pass  # CardPopupManager is now referenced via @onready

var dragged_card: Card = null
var mouseDownButtonPos: Vector2 = Vector2.INF
func _input(event):
	""" LEFT MOUSE BUTTON"""
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		""" CLICK """
		if event.pressed:
			mouseDownButtonPos = event.position
		else: 
			# Mouse released
			if dragged_card:
				# Notify game that drag ended (handles auto-casting)
				var card = dragged_card
				dragged_card = null
				cardDragEnded.emit(card, !isMousePointerInHandZone(), getObjectUnderMouse(CardLocation))
			elif event.position == mouseDownButtonPos:
				leftClick.emit(getObjectUnderMouse())
			mouseDownButtonPos = Vector2.INF
			
	""" RIGHT MOUSE BUTTON"""
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rightClick.emit(getCardUnderMouse())
	if event is InputEventMouseMotion: #Dragging
		var cardUnderMouse = getCardUnderMouse()
		if !dragged_card && mouseDownButtonPos != Vector2.INF:
			dragged_card = cardUnderMouse
			if dragged_card:
				cardDragStarted.emit(dragged_card)
		if dragged_card:
			cardDragPositionChanged.emit(dragged_card, !isMousePointerInHandZone(), getMousePositionHand())
		elif cardUnderMouse: #Just moving around
			onCardHover.emit(cardUnderMouse)

func getCardUnderMouse():
	if isMousePointerInHandZone():
		return getCardUnderMouseInHand()
	else:
		return getObjectUnderMouse(Card)
		
func getCardUnderMouseInHand() -> Card:
	if !isMousePointerInHandZone():
		return
	var hover_range = 50
	var _lift_amount = 1
	var closest_dist = hover_range + 1  # start bigger than range
	var cards = player_hand.get_children()
	var mouse_pos = get_viewport().get_mouse_position()
	var closest_card = null
	for card: Card in cards:
		var card_screen_pos = camera.unproject_position(card.global_transform.origin)
		var dist = mouse_pos.distance_to(card_screen_pos)
		if dist < hover_range && dist < closest_dist:
			closest_dist = dist
			closest_card = card
	return closest_card

func getMousePositionHand() -> Vector3:
	var mouse_position = get_viewport().get_mouse_position()
	
	# Add offset to the right when dragging a card so the card doesn't obscure the target
	if dragged_card:
		mouse_position.x += DRAG_OFFSET_X  # Offset to the right
	
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)
	var ray_end = ray_origin + ray_direction * 10000.0  # long ray

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1 << 7  

	var result = space_state.intersect_ray(query)

	if result and result.collider.name == "mouseInterceptPlane":
		return result.position
	else:
		return Vector3.ZERO  # or null, or handle as needed

func getObjectUnderMouse(target_class = Node3D) -> Node3D:
	var mouse_position = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)
	var ray_end = ray_origin + ray_direction * 1000.0  # long ray

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.set_collision_mask(pow(2, 1 - 1))

	
	var result = space_state.intersect_ray(query)
	var excludes = []
	while result:
		var collider = result.collider
		print(result.collider.name)
		# Check if the collider or any of its ancestors match the target class
		var current_node = collider
		while current_node:
			if is_instance_of(current_node, target_class):
				return current_node
			current_node = current_node.get_parent()
		
		# If not found, exclude this collider and continue searching
		excludes.push_back(collider)
		query.exclude = excludes
		result = space_state.intersect_ray(query)
	
	return null
		
func isMousePointerInHandZone() -> bool:
	return get_viewport().get_mouse_position().y > HAND_ZONE_CUTTOFF
