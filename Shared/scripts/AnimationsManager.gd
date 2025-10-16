extends Node

## AnimationsManager - Centralized animation system for the card game

const DRAW_POS = Vector3(0, 2, 1)
# Dictionary to track active tweens for each card
var active_card_tweens: Dictionary = {}

func _wait_for_card_animations(card: Card):
	"""Wait for any existing animations on this card to complete"""
	if not card:
		return
	
	var card_id = card.get_instance_id()
	
	# If there's an active tween for this card, wait for it to finish
	if active_card_tweens.has(card_id):
		var active_tween = active_card_tweens[card_id]
		if active_tween and active_tween.is_valid():
			await active_tween.finished

func _register_card_tween(card: Card, tween: Tween):
	"""Register a tween as active for a specific card"""
	if not card or not tween:
		return
	
	var card_id = card.get_instance_id()
	active_card_tweens[card_id] = tween
	
	# Clean up when tween finishes
	tween.finished.connect(func(): _cleanup_card_tween(card_id))

func _cleanup_card_tween(card_id: int):
	"""Remove the tween from active tracking"""
	if active_card_tweens.has(card_id):
		active_card_tweens.erase(card_id)

func get_tween_for_card(card: Card) -> Tween:
	"""Wait for existing animations and create a new tween for the card"""
	if not card:
		return null
	
	# Wait for any existing animations to complete
	await _wait_for_card_animations(card)
	
	# Create tween for smooth animation
	var tween = card.create_tween()
	_register_card_tween(card, tween)
	
	return tween

func animate_card_to_position(card: Card, target_position: Vector3, new_parent: Node3D = null):
	"""Animate a card moving to a target position with smooth CardRepresentation animation"""
	if not card:	
		return false
	var tween = await get_tween_for_card(card)
	
	# Handle reparenting if needed
	if new_parent:
		card.reparent(new_parent)
	# Move the card to the destination immediately
	card.setPositionWithoutMovingRepresentation(target_position, true)
	
	card.cardControlState = Card.CardControlState.MOVED_BY_GAME
	card.makeSmall()
	# Reset rotations
	card.rotation_degrees = Vector3(0, 0, 0)
	card.card_representation.rotation_degrees = Vector3(0, 0, 0)
	 
	# Configure tween for smooth animation to (0,0,0) which moves CardRepresentation to card's position
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card.card_representation, "position", Vector3(0, 0.2, 0), 0.6)
	
	return tween

func animate_combat_strike(attacker_card: Card, defender_card: Card):
	"""Animate the opponent card moving forward to strike the player's card"""
	if not attacker_card or not defender_card:
		return
	
	# Wait for existing animations and create new tween
	var tween = await get_tween_for_card(attacker_card)
	
	# Store original position
	var original_position = attacker_card.global_position
	
	# Calculate strike position (move towards the defender card)
	var defender_position = defender_card.global_position
	var direction = (defender_position - original_position).normalized()
	var strike_position = original_position + direction * 0.5  # Move 0.5 units forward
	
	# Animation parameters
	var strike_duration = 0.3
	var return_duration = 0.2
	
	# Configure tween for the strike animation
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Move forward to strike
	tween.tween_property(attacker_card, "global_position", strike_position, strike_duration)
	
	# Wait for the strike animation to complete
	await tween.finished
	
	# Wait a brief moment at the strike position
	await attacker_card.get_tree().create_timer(0.1).timeout
	
	# Create a new tween for the return animation
	var return_tween = attacker_card.create_tween()
	_register_card_tween(attacker_card, return_tween)
	
	return_tween.set_ease(Tween.EASE_IN)
	return_tween.set_trans(Tween.TRANS_QUART)
	return_tween.tween_property(attacker_card, "global_position", original_position, return_duration)
	
	# Wait for the return animation to complete
	await return_tween.finished

func show_floating_text(scene_node: Node3D, text_position: Vector3, text: String, color: Color):
	"""Show floating text animation at the specified position"""
	# Create a Label3D for the floating text
	var floating_label = Label3D.new()
	floating_label.text = text
	floating_label.modulate = color
	floating_label.font_size = 48
	floating_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floating_label.global_position = text_position + Vector3(0, 0.1, 0)  # Start slightly above the position
	
	# Add to scene
	scene_node.add_child(floating_label)
	
	# Create animation tween
	var tween = scene_node.create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
	
	# Animate upward movement and fade out
	var end_position = text_position + Vector3(0, 2, 0)  # Move up 2 units
	tween.tween_property(floating_label, "global_position", end_position, 2.0)
	tween.tween_property(floating_label, "modulate:a", 0.0, 2.0)  # Fade out alpha
	
	# Scale animation for emphasis
	floating_label.scale = Vector3.ZERO
	tween.tween_property(floating_label, "scale", Vector3.ONE, 0.3)
	
	# Wait for animation to complete then clean up
	await tween.finished
	floating_label.queue_free()

func animate_card_popup(card: Card):
	"""Animate card popup effect"""
	if card.cardControlState == Card.CardControlState.MOVED_BY_GAME:
		return
	
	var card_id = card.get_instance_id()
	if active_card_tweens.has(card_id):
		var active_tween = active_card_tweens[card_id]
		if active_tween and active_tween.is_valid():
			return  
	
	var pos := card.card_representation.position
	pos.z = lerp(pos.z, -0.6 + card.position.z, 0.4)
	card.card_representation.position = pos
	card.makeBig()
	# Removed glow effect - using outline color system instead

func animate_card_dragged(card: Card, target_pos: Vector3):
	"""Animate card being dragged to a position"""
	if card.cardControlState == Card.CardControlState.MOVED_BY_GAME:
		return
	
	# Check if card already has an active tween - if so, don't interfere
	var card_id = card.get_instance_id()
	if active_card_tweens.has(card_id):
		var active_tween = active_card_tweens[card_id]
		if active_tween and active_tween.is_valid():
			return  # Don't create popup animation if card is already animating
	card.cardControlState = Card.CardControlState.MOVED_BY_PLAYER
	card.card_representation.global_position = card.card_representation.global_position.lerp(target_pos, 0.4)
	card.card_representation.position.y = 0.1

func animate_card_to_rest_position(card: Card):
	"""Animate the card representation back to its rest position without blocking"""
	if !card:
		return
	print("Rest: " + card.name)
	
	# Check if card already has an active tween - if so, don't interfere
	var card_id = card.get_instance_id()
	if active_card_tweens.has(card_id):
		var active_tween = active_card_tweens[card_id]
		if active_tween and active_tween.is_valid():
			return  # Don't create popup animation if card is already animating
	# Wait for existing animations and create new tween
	var tween = await get_tween_for_card(card)
	
	# Animate position back to local zero
	tween.tween_property(card.card_representation, "position", Vector3.ZERO, 0.1)
	card.makeSmall()
	
	# Wait for animation to complete
	await tween.finished


func animate_card_to_cast_position(card: Card, isTurnedOver):
	"""Smoothly animate a card to the cast preparation position (shown immediately when casting starts)"""
	if not card:
		return
	print("MoveCast: " + card.name)
	
	# Wait for existing animations and create new tween
	var tween = await get_tween_for_card(card)
	card.cardControlState = Card.CardControlState.MOVED_BY_GAME
	card.makeBig()
	if isTurnedOver:
		turn_over(card)
	tween.set_ease(Tween.EASE_OUT)     
	tween.set_trans(Tween.TRANS_CUBIC)
	var preparation_position = Vector3(2.5, 1.4, 1)
	tween.tween_property(card.card_representation, "global_position", preparation_position, 0.6)
	# Wait for animation to complete
	print("Animate cast " + card.name, ", Time " + str(Time.get_ticks_msec()))
	await tween.finished
	card.cardControlState = Card.CardControlState.FREE
	print("Cast finished " + card.name, ", Time " + str(Time.get_ticks_msec()))
	
func animate_card_to_card_selection_position(card: Card):
	"""Smoothly animate a card to the right and alow player to chose cards"""
	if not card:
		return
	print("MoveSelect: " + card.name)
	
	# Wait for existing animations and create new tween
	var tween = await get_tween_for_card(card)
	
	card.cardControlState = Card.CardControlState.MOVED_BY_GAME
	var casting_position = Vector3(3.1, 1.4, 1)
	tween.tween_property(card.card_representation, "global_position", casting_position, 0.3)
	
	# Wait for animation to complete
	await tween.finished
	card.cardControlState = Card.CardControlState.FREE

func animateDraw(card: Card, from: Vector3, isTurnedOVer, cardsDrawnAtOnce: Array[Card]):
	var tween = await get_tween_for_card(card)
	card.card_representation.global_position = from
	tween.set_ease(Tween.EASE_OUT)     
	tween.set_trans(Tween.TRANS_CUBIC)
	if isTurnedOVer:
		turn_over(card)
		var spacing = 0.5
		var offset = Vector3(-(spacing * (cardsDrawnAtOnce.size() - 1)) / 2 + spacing * cardsDrawnAtOnce.find(card), 0, 0) 
		tween.tween_property(card.card_representation, "global_position", DRAW_POS + offset, 0.6)
		tween.tween_interval(0.3)
	tween.tween_property(card.card_representation, "position", Vector3(0, 0, 0), 0.3)
	return tween
	
func turn_over(card: Card, delay = 0.15):
	var t = card.create_tween()
	t.tween_interval(delay)
	t.tween_property(card.card_representation, "rotation", Vector3(0, 0, deg_to_rad(90)), 0.15)
	t.finished.connect(func():
		card.setFlip(true)
		card.card_representation.rotation.z = deg_to_rad(-90)
		card.create_tween().tween_property(card.card_representation, "rotation", Vector3(0, 0, 0), 0.15)
		)
