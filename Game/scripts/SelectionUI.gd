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
	hide()  # Hidden until a selection is started

func link(manager: SelectionManager):
	"""Wire this UI to a SelectionManager. After this call the UI shows/hides
	automatically and its buttons drive the manager — no manual show/hide needed."""
	manager.selection_started.connect(show)
	manager.selection_completed.connect(func(_s): hide())
	manager.selection_cancelled.connect(hide)
	manager.selection_updated.connect(_on_selection_updated)
	validate_pressed.connect(manager.validate_selection)
	cancel_pressed.connect(manager.cancel_selection)

func _on_selection_updated(description: String, can_validate: bool):
	set_description(description)
	set_validate_enabled(can_validate)

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
