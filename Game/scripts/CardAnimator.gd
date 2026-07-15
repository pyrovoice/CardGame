extends Node
class_name CardAnimator

var card: Card
var current_tween: Tween
var size_tween: Tween
var current_state: AnimationState = AnimationState.IDLE
var current_animation_priority: int = -1
var _current_animation_name: String = ""

var is_outside_hand_zone: bool = false
var target_drag_location: Vector3 = Vector3.ZERO
var drag_lerp_speed: float = 50

signal drag_started(card: Card)
signal drag_position_changed(card: Card, is_outside_hand: bool)
signal drag_ended(card: Card)

enum AnimationState { IDLE, ANIMATING, PLAYER_CONTROLLED }

static var ANIMATION_SPEED: float = 1.0

func _ready():
	card = get_parent() as Card
	name = "CardAnimator"
	set_process(false)

func get_tween(is_blocking: bool = true, priority: int = 1, animation_name: String = "") -> Tween:
	var tween = create_tween()
	tween.set_speed_scale(ANIMATION_SPEED)

	if is_blocking:
		if current_tween and current_tween.is_valid():
			if priority >= current_animation_priority:
				current_tween.kill()
			else:
				return null
		current_tween = tween
		current_animation_priority = priority
		_current_animation_name = animation_name
		tween.finished.connect(func():
			current_tween = null
			current_animation_priority = -1
			_current_animation_name = ""
		)
	return tween

func _process(delta):
	if current_state == AnimationState.PLAYER_CONTROLLED and target_drag_location != Vector3.ZERO:
		var current_pos = card.card_representation.global_position
		card.card_representation.global_position = current_pos.lerp(target_drag_location, drag_lerp_speed * delta)

# Shared helper used by move_to_position and cast_position
func _move_to_position(tween: Tween, target_pos: Vector3, duration: float, new_parent: Node3D = null) -> Tween:
	if new_parent:
		GameUtility.reparentCardWithoutMovingRepresentation(card, new_parent, target_pos)
	else:
		card.setPositionWithoutMovingRepresentation(target_pos, false)
	card.rotation_degrees = Vector3(0, 0, 0)
	card.card_representation.rotation_degrees = Vector3(0, 0, 0)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card.card_representation, "position", Vector3(0, 0, 0), duration)
	return tween

func move_to_position(target_pos: Vector3, duration: float = 0.2, new_parent: Node3D = null) -> Tween:
	var tween = get_tween(true, 2, "move_to_position")
	if tween:
		return _move_to_position(tween, target_pos, duration, new_parent)
	return null

func cast_position(should_turn_over: bool = false) -> Tween:
	make_big()
	if should_turn_over:
		_perform_flip_animation()
	var tween = get_tween(true, 2, "cast_position")
	if tween:
		return _move_to_position(tween, Vector3(2.5, 1.4, 1), 0.6)
	return null

func play_to_combat(combat_spot: Node3D, callback: Callable = Callable()) -> Tween:
	var tween = get_tween(true, 2, "play_to_combat")
	if tween:
		if callback:
			tween.finished.connect(callback)
		tween.tween_property(card.card_representation, "global_position", combat_spot.global_position + Vector3(0, 0.1, 0), 1.2)
		tween.tween_callback(func(): make_small())
	return tween

func return_to_hand(hand_position: Vector3) -> Tween:
	var tween = get_tween(true, 1, "return_to_hand")
	if tween:
		tween.tween_property(card.card_representation, "global_position", hand_position, 0.8)
	return tween

func slide_to_position(target_pos: Vector3, duration: float = 0.3) -> Tween:
	var tween = get_tween(true, 1, "slide_to_position")
	if tween:
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "position", target_pos, duration)
	return tween

func go_to_rest(duration: float = 0.15) -> Tween:
	if current_state != AnimationState.IDLE:
		return null
	var tween = get_tween(true, 0, "go_to_rest")
	if tween:
		tween.tween_property(card.card_representation, "position", Vector3.ZERO, duration)
		make_small()
	return tween

func animate_combat_strike(target_card: Card, callback: Callable = Callable()) -> Tween:
	var tween = get_tween(true, 2, "animate_combat_strike")
	if not tween:
		return null
	if callback:
		tween.finished.connect(callback)
	var original_position = card.global_position
	var direction = (target_card.global_position - original_position).normalized()
	var strike_position = original_position + direction * 50
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "global_position", strike_position, 0.3)
	tween.tween_interval(0.1)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(card, "global_position", original_position, 0.2)
	return tween

func lift_and_scale() -> Tween:
	var tween = get_tween(true, 0, "lift_and_scale")
	if tween:
		var target_pos = card.card_representation.position
		target_pos.z = -0.3
		target_pos.y = 0.1
		tween.tween_property(card.card_representation, "position", target_pos, 0.1)
		if card.is_small:
			make_big()
	return tween

func draw_card(from_position: Vector3, draw_position: Vector3, final_position: Vector3, delay: float = 0.0, flip_card: bool = false) -> Tween:
	var tween = get_tween(true, 1, "draw_card")
	if not tween:
		return null
	card.card_representation.global_position = from_position
	make_big()
	if delay > 0:
		tween.tween_interval(delay)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	if flip_card:
		tween.tween_property(card.card_representation, "global_position", draw_position, 0.6)
		_perform_flip_animation()
		tween.tween_interval(0.3)
		tween.tween_callback(func(): make_small())
		tween.tween_property(card.card_representation, "global_position", final_position, 0.15)
	else:
		tween.tween_callback(func(): make_small())
		tween.tween_property(card.card_representation, "global_position", final_position, 0.3)
	return tween

func _perform_flip_animation():
	var flip_tween = create_tween()
	flip_tween.set_speed_scale(ANIMATION_SPEED)
	flip_tween.set_ease(Tween.EASE_OUT_IN)
	flip_tween.tween_property(card.card_representation, "rotation_degrees:z", -90, 0.2)
	flip_tween.tween_callback(func(): card.setFlip(true))
	flip_tween.tween_callback(func(): card.card_representation.rotation_degrees.z = 90)
	flip_tween.tween_property(card.card_representation, "rotation_degrees:z", 0, 0.2)

# --- Size ---

# Card visual dimensions — card.scale is never changed; sizes are baked in world space.
# To swap states, update the BIG constants (SMALL is always the baseline).
const CARD_MESH_SIZE_SMALL        := Vector2(0.55, 0.55)
const CARD_MESH_SIZE_BIG          := Vector2(0.825, 1.335)  # 0.55*1.5, 0.89*1.5
const CARD_VIEWPORT_SIZE_SMALL    := Vector2i(150, 150)
const CARD_VIEWPORT_SIZE_BIG      := Vector2i(198, 267)
const CARD_2D_POS_SMALL           := Vector2(-25, 0)
const CARD_2D_POS_BIG             := Vector2(0, 0)
const CARD_COLLISION_SIZE_SMALL   := Vector3(0.54, 0.01, 0.6)  # Matches BoxShape3D_card in Card.tscn
const CARD_COLLISION_SIZE_BIG     := Vector3(0.54, 0.01, 0.915)
const CARD_HIGHLIGHT_SCALE_SMALL  := Vector3(1.05, 1, 0.65)
const CARD_HIGHLIGHT_SCALE_BIG    := Vector3(1.03, 1, 1.02)
const makeSmallTime = 0.15
const makeBigTime = 0.1

func _setup_size_tween() -> Tween:
	if size_tween and size_tween.is_valid():
		size_tween.kill()
	size_tween = create_tween()
	size_tween.set_parallel()
	return size_tween

func make_small() -> Tween:
	if card.is_small:
		return null
	card.is_small = true
	card.highlight_mesh.scale = CARD_HIGHLIGHT_SCALE_SMALL
	var t = _setup_size_tween()
	t.tween_property(card.card_representation.mesh, "size", CARD_MESH_SIZE_SMALL, makeSmallTime)
	t.tween_property(card.sub_viewport, "size", CARD_VIEWPORT_SIZE_SMALL, makeSmallTime)
	t.tween_property(card.card_2d, "position", CARD_2D_POS_SMALL, makeSmallTime)
	t.tween_callback(func(): (card.collision_shape_3d.shape as BoxShape3D).size = CARD_COLLISION_SIZE_SMALL)
	return t

func make_big() -> Tween:
	if not card.is_small:
		return null
	card.is_small = false
	var t = _setup_size_tween()
	t.tween_property(card.card_representation.mesh, "size", CARD_MESH_SIZE_BIG, makeBigTime)
	t.tween_property(card.sub_viewport, "size", CARD_VIEWPORT_SIZE_BIG, makeBigTime)
	t.tween_property(card.card_2d, "position", CARD_2D_POS_BIG, makeBigTime)
	t.finished.connect(func():
		(card.collision_shape_3d.shape as BoxShape3D).size = CARD_COLLISION_SIZE_BIG
		card.highlight_mesh.scale = CARD_HIGHLIGHT_SCALE_BIG
	)
	return t

# --- State / drag ---

func can_go_to_rest() -> bool:
	return current_state == AnimationState.IDLE

func is_available_for_interaction() -> bool:
	return current_state == AnimationState.IDLE

func is_being_dragged() -> bool:
	return target_drag_location != Vector3.ZERO

func start_player_control():
	current_state = AnimationState.PLAYER_CONTROLLED

func end_player_control():
	if current_state == AnimationState.PLAYER_CONTROLLED:
		current_state = AnimationState.IDLE
		_check_for_rest_positioning()

func _check_for_rest_positioning():
	if current_state == AnimationState.IDLE and can_go_to_rest():
		await get_tree().process_frame
		if current_state == AnimationState.IDLE and card.card_representation.position.distance_to(Vector3.ZERO) > 0.1:
			go_to_rest()

func start_drag():
	if current_state != AnimationState.PLAYER_CONTROLLED:
		if current_tween and current_tween.is_valid():
			current_tween.kill()
			current_tween = null
		make_small()
		current_state = AnimationState.PLAYER_CONTROLLED
		set_process(true)
		drag_started.emit(card)

func end_drag(target_destination = null):
	target_drag_location = Vector3.ZERO
	set_process(false)
	current_state = AnimationState.IDLE
	if not target_destination:
		go_to_rest()
	drag_ended.emit(card)

func update_drag_position(target_pos: Vector3, is_outside_hand: bool = false):
	if current_state != AnimationState.PLAYER_CONTROLLED:
		return
	target_drag_location = target_pos
	if is_outside_hand_zone != is_outside_hand:
		is_outside_hand_zone = is_outside_hand
		drag_position_changed.emit(card, is_outside_hand_zone)
