extends Node3D
class_name PlayerControl

# Reference to the CardPopupManager in the UI
@onready var card_popup_manager: CardPopupManager = $"../UI/CardPopupManager"
var previoustween: Tween = null

@onready var player_hand: Node3D = $"../Camera3D/PlayerHand"
@onready var mouse_intercept_plane: StaticBody3D = $"../Camera3D/mouseInterceptPlane"
@onready var camera: Camera3D = $"../Camera3D"

signal tryMoveCard(card: Card, target: Node3D)
signal displayCardPopup(card: Card)

const HAND_ZONE_CUTTOFF = 500

# Popup positioning constants (same as CardAlbum)
const POPUP_LEFT_MARGIN = 5
const ENLARGED_CARD_HEIGHT = 600

func _ready():
	pass  # CardPopupManager is now referenced via @onready

var cardInHandUnderMouse: Card = null
func _process(_delta):
	cardInHandUnderMouse = null
	if dragged_card:
		dragged_card.dragged(getMousePositionHand())
		return
	else:
		dragged_card = null
	# First check for cards in hand zone (existing logic)
	if isMousePointerInHandZone():
		var hover_range = 130
		var _lift_amount = 1
		var closest_card = null
		var closest_dist = hover_range + 1  # start bigger than range
		var cards = player_hand.get_children()
		var mouse_pos = get_viewport().get_mouse_position()
		for card: Card in cards:
			var card_screen_pos = camera.unproject_position(card.global_transform.origin)
			var dist = mouse_pos.distance_to(card_screen_pos)
			if dist < hover_range && dist < closest_dist:
				closest_dist = dist
				closest_card = card
		if closest_card:
			closest_card.popUp()
			cardInHandUnderMouse = closest_card
	

var dragged_card: Card = null
func _input(event):
	# The CardPopupManager will handle hiding itself
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if cardInHandUnderMouse:
				dragged_card = cardInHandUnderMouse
			else:
				var clickedCard: Card = getObjectUnderMouse(Card)
				if clickedCard:
					print(clickedCard.cardData.cardName)
					dragged_card = clickedCard
		else:
			if !event.pressed && dragged_card && !isMousePointerInHandZone():
				var target = getObjectUnderMouse(CombatantFightingSpot)
				if not target:
					target = getObjectUnderMouse(PlayerBase)
				tryMoveCard.emit(dragged_card, target)
			dragged_card = null
	
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var target_card: Card = null
			
			# First check if there's a card under mouse in hand
			if cardInHandUnderMouse:
				target_card = cardInHandUnderMouse
			else:
				# Check for cards in play (combat zones)
				target_card = getCardUnderMouse()
			
			if target_card:
				displayCardPopup.emit(target_card)
				showCardPopup(target_card)
			
			# Keep the original debug functionality
			getObjectUnderMouse()

func getCardUnderMouse() -> Card:
	"""Get any card under mouse cursor, whether in hand or in play"""
	# Use the existing getObjectUnderMouse function to find a Card
	return getObjectUnderMouse(Card) as Card

func showCardPopup(card: Card):
	if card == null:
		return
	
	# Use the shared popup system with enlarged mode and left-side positioning
	if card_popup_manager and card_popup_manager.has_method("show_card_popup"):
		var popup_position = _calculate_game_popup_position()
		card_popup_manager.show_card_popup(card.cardData, popup_position, CardPopupManager.DisplayMode.ENLARGED)

func _calculate_game_popup_position() -> Vector2:
	"""Calculate the position for card popup in game view (left side of screen)"""
	var viewport_size = get_viewport().get_visible_rect().size
	# Use the actual enlarged viewport height for positioning
	var vertical_center = (viewport_size.y - ENLARGED_CARD_HEIGHT) / 2
	return Vector2(POPUP_LEFT_MARGIN, vertical_center)

func getMousePositionHand() -> Vector3:
	var mouse_position = get_viewport().get_mouse_position()
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
	var ray_end = ray_origin + ray_direction * 10.0  # long ray

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF 
	DebugDraw3D.draw_line(ray_origin, ray_end, Color.RED, 1000)
	var result = space_state.intersect_ray(query)
	var excludes = []
	var searchCounter = 0
	while result:
		var collider = result.collider
		searchCounter+=1
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
