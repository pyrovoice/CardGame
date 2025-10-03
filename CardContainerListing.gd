extends Control
class_name CardContainerVizualizer

@onready var scroll_container: ScrollContainer = $scrollContainer
const SCROLL_SPEED = 20
@onready var h_box_container: HBoxContainer = $scrollContainer/HBoxContainer
var card2DScene = preload("res://Shared/scenes/Card2D.tscn")


func setContainer(container: CardContainer):
	if !container:
		return
	for c in h_box_container.get_children():
		c.queue_free()
	for c in container.cards:
		var card2D: Card2D = card2DScene.instantiate()
		h_box_container.add_child(card2D)
		card2D.set_card(c)
		
		
func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_on_scroll_up()
					get_viewport().set_input_as_handled()
				MOUSE_BUTTON_WHEEL_DOWN:
					_on_scroll_down()
					get_viewport().set_input_as_handled()

func _on_scroll_up():
	scroll_container.scroll_horizontal -= SCROLL_SPEED

func _on_scroll_down():
	scroll_container.scroll_horizontal += SCROLL_SPEED
