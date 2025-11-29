extends Node

## AnimationsManager - Centralized non-card animation system
## Card animations use CardAnimator directly: card.getAnimator().method_name()

const DRAW_POS = Vector3(0, 2, 1)

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

func animate_card_to_card_selection_position(card: Card):
	"""Smoothly animate a card to the right and allow player to choose cards"""
	if not card:
		return
	print("MoveSelect: " + card.name)
	
	var casting_position = Vector3(3.1, 1.4, 1)
	var animator = card.getAnimator()
	if animator:
		animator.move_to_position(casting_position, 0.3)

func animateDraw(card: Card, from: Vector3, isTurnedOVer, cardsDrawnAtOnce: Array[Card]):
	"""Complex draw animation sequence for multiple cards"""
	card.card_representation.global_position = from
	if isTurnedOVer:
		turn_over(card)
	
	var spacing = 0.5
	var offset = Vector3(-(spacing * (cardsDrawnAtOnce.size() - 1)) / 2 + spacing * cardsDrawnAtOnce.find(card), 0, 0)
	
	# Create a custom tween for this complex animation sequence
	var tween = card.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card.card_representation, "global_position", DRAW_POS + offset, 0.6)
	tween.tween_interval(0.3)
	
	var animator = card.getAnimator()
	if animator:
		tween.tween_callback(func(): animator.make_small())
	
	tween.tween_property(card.card_representation, "position", Vector3(0, 0, 0), 0.3)
	return tween
	
func turn_over(card: Card, delay = 0.15):
	"""Animate card flip-over effect with rotation and state change"""
	var t = card.create_tween()
	t.tween_interval(delay)
	t.tween_property(card.card_representation, "rotation", Vector3(0, 0, deg_to_rad(90)), 0.15)
	t.finished.connect(func():
		card.setFlip(true)
		card.card_representation.rotation.z = deg_to_rad(-90)
		card.create_tween().tween_property(card.card_representation, "rotation", Vector3(0, 0, 0), 0.15)
	)
