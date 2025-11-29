extends Node
class_name CardAnimator

var card: Card
var current_tween: Tween
var size_tween: Tween  # Dedicated tween for make_big/make_small operations
var current_state: AnimationState = AnimationState.IDLE
var current_animation_priority: int = -1  # Track current animation priority (-1 = no animation)

# Drag state tracking
var is_outside_hand_zone: bool = false
var target_drag_location: Vector3 = Vector3.ZERO
var drag_lerp_speed: float = 50  # Lerp speed for drag movement

# Signals for drag state changes
signal drag_started(card: Card)
signal drag_position_changed(card: Card, is_outside_hand: bool)
signal drag_ended(card: Card)

enum AnimationState {
	IDLE,
	ANIMATING,
	PLAYER_CONTROLLED
}



# Global animation speed multiplier - 1.0 is normal speed, 2.0 is double speed, 0.5 is half speed
const ANIMATION_SPEED: float = 1.0
func _ready():
	card = get_parent() as Card
	name = "CardAnimator"
	set_process(false)  # Only process when actively dragging

func get_tween(is_blocking: bool = true, priority: int = 1) -> Tween:
	"""Create and configure a tween with common settings. Priority: 0=lowest, 1=normal, 2=highest"""
	var tween = create_tween()
	tween.set_speed_scale(ANIMATION_SPEED)
	
	if is_blocking:
		# Check if we should interrupt current animation based on priority
		if current_tween and current_tween.is_valid():
			if priority >= current_animation_priority:
				current_tween.kill()
			else:
				return null  # Cannot interrupt, return null to indicate failure
		
		current_tween = tween
		current_animation_priority = priority
		tween.finished.connect(func(): 
			current_tween = null
			current_animation_priority = -1
		)
	
	return tween



func _process(delta):
	"""Handle drag movement with smooth lerping"""
	if current_state == AnimationState.PLAYER_CONTROLLED and target_drag_location != Vector3.ZERO:
		# Smoothly lerp toward target drag location
		var current_pos = card.card_representation.global_position
		var new_pos = current_pos.lerp(target_drag_location, drag_lerp_speed * delta)
		card.card_representation.global_position = new_pos

func _animate_move_to_position(tween: Tween, data: Dictionary) -> Tween:
	var target_pos = data.get("target_position", Vector3.ZERO)
	var duration = data.get("duration", 0.2)
	var new_parent = data.get("new_parent", null)
	
	# Handle reparenting if needed
	if new_parent:
		card.reparent(new_parent)
	
	# Move the card to the destination immediately (legacy behavior)
	card.setPositionWithoutMovingRepresentation(target_pos, false)
	
	# Set card control state and reset rotations
	card.rotation_degrees = Vector3(0, 0, 0)
	card.card_representation.rotation_degrees = Vector3(0, 0, 0)
	
	# Configure tween with legacy easing for smooth animation to rest position
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card.card_representation, "position", Vector3(0, 0, 0), duration)
	
	return tween

func _animate_play_to_combat(tween: Tween, data: Dictionary) -> Tween:
	var combat_spot = data.get("combat_spot")
	var duration = data.get("duration", 1.2)
	
	if combat_spot:
		var target_pos = combat_spot.global_position + Vector3(0, 0.1, 0)
		tween.tween_property(card.card_representation, "global_position", target_pos, duration)
		tween.tween_callback(make_small)
	
	return tween

func _animate_return_to_hand(tween: Tween, data: Dictionary) -> Tween:
	var hand_position = data.get("hand_position", Vector3.ZERO)
	var duration = data.get("duration", 0.8)
	
	tween.tween_property(card.card_representation, "global_position", hand_position, duration)
	return tween

func _animate_to_rest(tween: Tween, data: Dictionary) -> Tween:
	# Always animate smoothly to rest position
	var duration = 0.15
	
	# Animate position back to local zero (legacy behavior)
	tween.tween_property(card.card_representation, "position", Vector3.ZERO, duration)
	make_small()
	
	return tween

func _check_for_rest_positioning():
	# Only auto-rest if the card is truly idle and not about to be cast
	if current_state == AnimationState.IDLE and can_go_to_rest():
		# Check if card representation is not at rest position (Vector3.ZERO)
		# Add a small delay to allow casting logic to take precedence
		await get_tree().process_frame
		if current_state == AnimationState.IDLE and card.card_representation.position.distance_to(Vector3.ZERO) > 0.1:
			go_to_rest()

# Declarative animation methods
func move_to_position(target_pos: Vector3, duration: float = 0.2, new_parent: Node3D = null) -> Tween:
	var tween = get_tween(true, 2)  # High priority
	if tween:
		return _animate_move_to_position(tween, {
			"target_position": target_pos,
			"duration": duration,
			"new_parent": new_parent
		})
	return null

func play_to_combat(combat_spot: Node3D, callback: Callable = Callable()) -> Tween:
	var tween = get_tween(true, 2)  # High priority
	if tween:
		if callback:
			tween.finished.connect(callback)
		return _animate_play_to_combat(tween, {
			"combat_spot": combat_spot,
			"duration": 1.2
		})
	return null

func return_to_hand(hand_position: Vector3) -> Tween:
	var tween = get_tween(true, 1)  # Normal priority
	if tween:
		return _animate_return_to_hand(tween, {
			"hand_position": hand_position,
			"duration": 0.8
		})
	return null

func slide_to_position(target_pos: Vector3, duration: float = 0.3) -> Tween:
	"""Slide card to new position without affecting representation or triggering rest"""
	var tween = get_tween(true, 1)  # Normal priority
	if tween:
		return _animate_slide_to_position(tween, {
			"target_position": target_pos,
			"duration": duration
		})
	return null

func cast_position(should_turn_over: bool = false) -> Tween:
	"""Animate card to cast preparation position"""
	# Make card big and turn over if needed (parallel animations)
	make_big()
	if should_turn_over:
		turn_over()
	
	# Move to cast preparation position with high priority
	var preparation_position = Vector3(2.5, 1.4, 1)
	var tween = get_tween(true, 2)  # High priority
	if tween:
		return _animate_move_to_position(tween, {
			"target_position": preparation_position,
			"duration": 0.6,
			"new_parent": null
		})
	return null

func go_to_rest() -> Tween:
	# DRAG FIX: Block rest during dragging
	if is_being_dragged():
		return null
	
	var tween = get_tween(true, 0)  # Lowest priority
	if tween:
		return _animate_to_rest(tween, {})
	return null

func can_go_to_rest() -> bool:
	return current_state == AnimationState.IDLE

func start_player_control():
	current_state = AnimationState.PLAYER_CONTROLLED

func end_player_control():
	if current_state == AnimationState.PLAYER_CONTROLLED:
		current_state = AnimationState.IDLE
		_check_for_rest_positioning()

func start_drag():
	"""Start dragging the card - interrupts current animations if possible"""
	if current_state != AnimationState.PLAYER_CONTROLLED:
		# Interrupt current animation if any
		if current_tween and current_tween.is_valid():
			current_tween.kill()
			current_tween = null
		
		current_state = AnimationState.PLAYER_CONTROLLED
		set_process(true)  # Enable _process for lerping
		drag_started.emit(card)

func end_drag(target_destination = null):
	"""End dragging the card - moves to cast position or returns to rest"""
	target_drag_location = Vector3.ZERO  # Clear drag target
	set_process(false)  # Disable _process
	
	if target_destination:
		# Card was dropped on a valid target - move to cast position
		current_state = AnimationState.IDLE
		# Don't call _check_for_rest_positioning() - let the game handle casting
	else:
		# Card was dropped in empty space - return to rest
		end_player_control()
	
	drag_ended.emit(card)

func update_drag_position(target_pos: Vector3, is_outside_hand: bool = false):
	"""Update drag target position - uses lerp in _process for smooth movement"""
	if current_state != AnimationState.PLAYER_CONTROLLED:
		return
	
	# Update target position - _process will handle the lerping
	target_drag_location = target_pos
	
	# Track and notify if outside hand zone changes
	if is_outside_hand_zone != is_outside_hand:
		is_outside_hand_zone = is_outside_hand
		drag_position_changed.emit(card, is_outside_hand_zone)

func is_being_dragged() -> bool:
	"""Check if this card is currently being dragged by the player"""
	return target_drag_location != Vector3.ZERO

func _animate_combat_strike(tween: Tween, data: Dictionary) -> Tween:
	"""Animate card striking another card in combat"""
	var target_card = data.get("target_card")
	var duration = data.get("duration", 0.3)
	var return_duration = data.get("return_duration", 0.2)
	
	if not target_card:
		return tween
	
	# Store original position
	var original_position = card.global_position
	
	# Calculate strike position
	var target_position = target_card.global_position
	var direction = (target_position - original_position).normalized()
	var strike_position = original_position + direction * 0.5
	
	# Configure tween for strike
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Move forward to strike
	tween.tween_property(card, "global_position", strike_position, duration)
	
	# Wait briefly at strike position
	tween.tween_interval(0.1)
	
	# Return to original position
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(card, "global_position", original_position, return_duration)
	
	return tween

func animate_combat_strike(target_card: Card, callback: Callable = Callable()) -> Tween:
	"""Animate card striking another card in combat"""
	var tween = get_tween(true, 2)  # High priority
	if tween:
		if callback:
			tween.finished.connect(callback)
		return _animate_combat_strike(tween, {
			"target_card": target_card,
			"duration": 0.3,
			"return_duration": 0.2
		})
	return null

func animate_combat_strike_awaitable(target_card: Card) -> Tween:
	"""Animate card striking another card in combat - returns awaitable tween"""
	var data = {
		"target_card": target_card,
		"duration": 0.3,
		"return_duration": 0.2
	}
	
	# Create tween directly for awaitable version
	var tween = create_tween()
	tween.set_speed_scale(ANIMATION_SPEED)
	return _animate_combat_strike(tween, data)

func make_small() -> Tween:
	"""Make card small with animation"""
	if card.is_small:
		return null
	
	# Kill any existing size animation
	if size_tween and size_tween.is_valid():
		size_tween.kill()
	
	var tween = get_tween(false)  # Non-blocking parallel animation
	return _animate_make_small(tween, {})

func make_big() -> Tween:
	"""Make card big with animation"""
	if not card.is_small:
		return null
	
	# Kill any existing size animation
	if size_tween and size_tween.is_valid():
		size_tween.kill()
	
	var tween = get_tween(false)  # Non-blocking parallel animation
	return _animate_make_big(tween, {})

func lift_and_scale() -> Tween:
	"""Lift card upward and make it big - used for hover/highlight effects"""
	print("[DEBUG] lift_and_scale called on card: ", card.name)
	var tween = get_tween(true, 0)  # Lowest priority
	if tween:
		return _animate_lift_and_scale(tween, {})
	return null

const makeSmallTime = 0.02
func _animate_make_small(tween: Tween, _data: Dictionary) -> Tween:
	"""Animate card to small size"""
	if card.is_small:
		return tween
	
	card.is_small = true
	card.highlight_mesh.scale = Vector3(1.05, 1, 0.65)  # Adjust Y scale to match card ratio
	
	# Use dedicated size_tween instead of passed tween
	size_tween = create_tween()
	size_tween.set_parallel()
	size_tween.tween_property(card.card_representation.mesh, "size", Vector2(0.55, 0.55), makeSmallTime)
	size_tween.tween_property(card.sub_viewport, "size", Vector2i(150, 150), makeSmallTime)
	size_tween.tween_property(card, "scale", Vector3(1, 1, 1), makeSmallTime)
	size_tween.tween_property(card.card_2d, "position", Vector2(-25, 0), makeSmallTime)
	
	# Adjust collision shape
	size_tween.tween_callback(func(): (card.collision_shape_3d.shape as BoxShape3D).size.z = 0.55)
	return tween

const makeBigTime = 0.1
func _animate_make_big(tween: Tween, _data: Dictionary) -> Tween:
	"""Animate card to big size"""
	if not card.is_small:
		return tween
	
	card.is_small = false
	
	# Use dedicated size_tween instead of passed tween
	size_tween = create_tween()
	size_tween.set_parallel()
	size_tween.tween_property(card.card_representation.mesh, "size", Vector2(0.55, 0.89),makeBigTime)
	size_tween.tween_property(card.sub_viewport, "size", Vector2i(198, 267), makeBigTime)
	size_tween.tween_property(card, "scale", Vector3(1.5, 1.5, 1.5), makeBigTime)
	size_tween.tween_property(card.card_2d, "position", Vector2(0, 0), makeBigTime)
	
	# Connect to finished signal to execute cleanup after parallel animations complete
	size_tween.finished.connect(func():
		(card.collision_shape_3d.shape as BoxShape3D).size.y = 0.89
		card.highlight_mesh.scale = Vector3(1.03, 1, 1.02)  # Back to normal scale
	)
	return tween

func _animate_lift_and_scale(tween: Tween, _data: Dictionary) -> Tween:
	"""Animate card lift upward and scale - for hover/highlight effects"""
	# Calculate target lift position - lift the card up on Z axis
	var target_pos = card.card_representation.position
	target_pos.z = -0.3  # Move further up on Z axis for better visibility
	target_pos.y = 0.1   # Slight Y lift as well
	
	# Use tween for smooth position change
	tween.tween_property(card.card_representation, "position", target_pos, 0.1)
	
	# Make card big if it's currently small (use direct call)
	if card.is_small:
		make_big()
	
	return tween

func _animate_slide_to_position(tween: Tween, data: Dictionary) -> Tween:
	"""Animate card sliding to new position without affecting representation"""
	var target_pos = data.get("target_position", Vector3.ZERO)
	var duration = data.get("duration", 0.3)
	
	# Smoothly animate the card's logical position without touching representation
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "position", target_pos, duration)
	
	return tween

func draw_card(from_position: Vector3, draw_position: Vector3, final_position: Vector3, delay: float = 0.0, flip_card: bool = false) -> Tween:
	"""Animate card being drawn from deck to hand through intermediate draw position"""
	var tween = get_tween(true, 1)  # Normal priority
	if tween:
		return _animate_draw_card(tween, {
			"from_position": from_position,
			"draw_position": draw_position, 
			"final_position": final_position,
			"delay": delay,
			"flip_card": flip_card
		})
	return null

func turn_over() -> Tween:
	"""Turn card over (flip animation)"""
	var tween = get_tween(false)  # Non-blocking parallel animation
	return _animate_turn_over(tween, {})

func _animate_turn_over(tween: Tween, _data: Dictionary) -> Tween:
	"""Animate card flip over"""
	tween.set_parallel()
	tween.tween_property(card, "rotation_degrees:y", 180, 0.3)
	tween.tween_callback(func():
		card.setFlip(not card.is_facedown)
		card.rotation_degrees.y = 0
	)
	return tween

func _animate_draw_card(tween: Tween, data: Dictionary) -> Tween:
	"""Animate card draw sequence: deck -> draw position -> hand position"""
	var from_pos = data.get("from_position", Vector3.ZERO)
	var draw_pos = data.get("draw_position", Vector3(0, 2, 1))
	var final_position = data.get("final_position", Vector3(0, 0, 0))
	var delay = data.get("delay", 0.0)
	var flip_card = data.get("flip_card", false)
	
	# Set initial position
	card.card_representation.global_position = from_pos
	
	# Add delay for staggered effect
	if delay > 0:
		tween.tween_interval(delay)
	
	# Configure tween for smooth draw animation
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	if flip_card:
		# Move from deck to draw position, flip, then move to hand
		tween.tween_property(card.card_representation, "global_position", draw_pos, 0.6)
		_perform_flip_animation()
		tween.tween_interval(0.3)
		tween.tween_callback(func(): make_small())
		tween.tween_property(card.card_representation, "global_position", final_position, 0.15)
	else:
		# Direct move to hand with small size
		make_small()
		tween.tween_property(card.card_representation, "global_position", final_position, 0.3)
	
	return tween

func _perform_flip_animation():
	"""Helper method to perform card flip animation during draw sequence"""
	var flip_tween = create_tween()
	flip_tween.tween_property(card.card_representation, "rotation_degrees:z", -90, 0.2)
	flip_tween.tween_callback(func(): card.setFlip(true))
	flip_tween.tween_callback(func(): card.card_representation.rotation_degrees.z = 90)
	flip_tween.tween_property(card.card_representation, "rotation_degrees:z", 0, 0.2)

func is_available_for_interaction() -> bool:
	"""Check if the card is available for player interaction (not being animated by game)"""
	return current_state == AnimationState.IDLE
