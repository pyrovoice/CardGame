extends Control
class_name SelectionUI

@onready var description_label: Label = $Panel/VBoxContainer/DescriptionLabel
@onready var validate_button: Button = $Panel/VBoxContainer/ButtonContainer/ValidateButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonContainer/CancelButton

signal validate_pressed()
signal cancel_pressed()

func _ready():
	validate_button.pressed.connect(_on_validate_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func _on_validate_pressed():
	validate_pressed.emit()

func _on_cancel_pressed():
	cancel_pressed.emit()

func set_description(text: String):
	if description_label:
		description_label.text = text

func set_validate_enabled(enabled: bool):
	if validate_button:
		validate_button.disabled = not enabled
