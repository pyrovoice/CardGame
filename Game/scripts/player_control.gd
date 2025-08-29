extends Node3D
class_name PlayerControl
# Remove the old popup references - they'll be handled by CardPopupManager
var card_popup_manager: Control
var previoustween: Tween = null

@onready var player_hand: Node3D = $"../Camera3D/PlayerHand"
@onready var mouse_intercept_plane: StaticBody3D = $"../Camera3D/mouseInterceptPlane"
@onready var camera: Camera3D = $"../Camera3D"

signal tryPlayCard(card: Card, target: Node3D)
signal displayCardPopup(card: Card)

const HAND_ZONE_CUTTOFF = 500

func _ready():
	# Load the shared popup manager
	var popup_scene = preload("res://Shared/scenes/CardPopupManager.tscn")
	card_popup_manager = popup_scene.instantiate()
	get_parent().add_child(card_popup_manager)

var cardUnderMouse: Card = null
func _process(delta):
	cardUnderMouse = null
	if dragged_card:
		dragged_card.dragged(getMousePositionHand())
		return
	else:
		dragged_card = null
	if isMousePointerInHandZone():
		var hover_range = 130
		var lift_amount = 1
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
			cardUnderMouse = closest_card
	

var dragged_card: Card = null
func _input(event):
	# The CardPopupManager will handle hiding itself
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed && cardUnderMouse:
			dragged_card = cardUnderMouse
		else:
			if !event.pressed && dragged_card && !isMousePointerInHandZone():
				tryPlayCard.emit(dragged_card, getObjectUnderMouse(CombatantFightingSpot))
			dragged_card = null
	
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed && cardUnderMouse:
			displayCardPopup.emit(cardUnderMouse)
			showCardPopup(cardUnderMouse)
		if event.pressed:
			getObjectUnderMouse()

func showCardPopup(card: Card):
	if card == null:
		return
	
	# Use the shared popup system
	if card_popup_manager and card_popup_manager.has_method("show_card_popup"):
		card_popup_manager.show_card_popup(card.cardData)

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
	while result && !is_instance_of(result.collider, target_class):
		excludes.push_back(result.collider)
		query.exclude = excludes
		result = space_state.intersect_ray(query)
	if result && is_instance_of(result.collider, target_class):
		return result.collider
	return null
		
func isMousePointerInHandZone() -> bool:
	return get_viewport().get_mouse_position().y > HAND_ZONE_CUTTOFF
