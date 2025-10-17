extends Node3D
class_name PlayerControl

# Reference to the CardPopupManager in the UI
@onready var card_popup_manager: CardPopupManager = $"../UI/CardPopupManager"

@onready var player_hand: Node3D = $"../Camera3D/PlayerHand"
@onready var mouse_intercept_plane: StaticBody3D = $"../Camera3D/mouseInterceptPlane"
@onready var camera: Camera3D = $"../Camera3D"

signal tryMoveCard(card: Card, target: Node3D)
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

var cardInHandUnderMouse: Card = null
var currently_highlighted_card: Card = null
var currently_highlighted_target: Node3D = null


func updateHighlights():
	"""Update which objects should be highlighted based on current state"""
	var target_card: Card = null
	
	# Determine which card should be highlighted
	if isMousePointerInHandZone():
		# In hand zone - highlight card that would be popped up
		target_card = cardInHandUnderMouse
	
	# Update highlight state
	if currently_highlighted_card != target_card:
		# Remove highlight from previously highlighted card
		if currently_highlighted_card:
			currently_highlighted_card.highlight(false)
		
		# Add highlight to new target card
		if target_card:
			target_card.highlight(true)
		
		currently_highlighted_card = target_card

func clearTargetHighlight():
	"""Clear the current target highlight"""
	if currently_highlighted_target and currently_highlighted_target.has_method("highlight"):
		currently_highlighted_target.highlight(false)
	currently_highlighted_target = null
	

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
				cardDragEnded.emit(dragged_card, !isMousePointerInHandZone(), getObjectUnderMouse(CardLocation))
			elif event.position == mouseDownButtonPos:
				print("Left click ")
				leftClick.emit(getObjectUnderMouse())
			dragged_card = null
			mouseDownButtonPos = Vector2.INF
			
	""" RIGHT MOUSE BUTTON"""
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var target_card: Card = null
			
			# First check if there's a card under mouse in hand
			if cardInHandUnderMouse:
				target_card = cardInHandUnderMouse
			else:
				# Check for cards in play (combat zones)
				target_card = getCardUnderMouse()
			rightClick.emit(target_card)
	if event is InputEventMouseMotion:
		if !dragged_card && mouseDownButtonPos != Vector2.INF:
			if isMousePointerInHandZone():
				dragged_card = cardInHandUnderMouse
			else:
				dragged_card = getObjectUnderMouse(Card)
			if dragged_card:
				cardDragStarted.emit(dragged_card)
		if dragged_card:
			var is_outside_hand = !isMousePointerInHandZone()
			cardDragPositionChanged.emit(dragged_card, is_outside_hand, getMousePositionHand())
		
		if isMousePointerInHandZone():
			var hover_range = 50
			var _lift_amount = 1
			var closest_dist = hover_range + 1  # start bigger than range
			var cards = player_hand.get_children()
			var mouse_pos = get_viewport().get_mouse_position()
			var closest_card
			for card: Card in cards:
				var card_screen_pos = camera.unproject_position(card.global_transform.origin)
				var dist = mouse_pos.distance_to(card_screen_pos)
				if dist < hover_range && dist < closest_dist:
					closest_dist = dist
					closest_card = card
			
			if closest_card && closest_card != cardInHandUnderMouse:
				AnimationsManagerAL.animate_card_to_rest_position(cardInHandUnderMouse)
				AnimationsManagerAL.animate_card_popup(closest_card)
				cardInHandUnderMouse = closest_card
			elif !closest_card && cardInHandUnderMouse != null:
				AnimationsManagerAL.animate_card_to_rest_position(cardInHandUnderMouse)
				cardInHandUnderMouse = null

			# Update highlights based on current mouse position
			updateHighlights()
			
func getCardUnderMouse() -> Card:
	"""Get any card under mouse cursor, whether in hand or in play"""
	# Use the existing getObjectUnderMouse function to find a Card
	return getObjectUnderMouse(Card) as Card

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
