extends Control
class_name RunStartUI

const GAME_VIEW = "uid://diasc2vlc4hu1"

@onready var start: Button = $Button
@onready var grid_container: GridContainer = $GridContainer

var _button_group := ButtonGroup.new()

func _ready() -> void:
	# Remove scene placeholders
	for child in grid_container.get_children():
		child.queue_free()

	# Spawn one toggle button per unlocked archetype
	for archetype_id in PlayerDataAL.unlocked_archetypes:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 80)
		btn.text = archetype_id.capitalize()
		btn.toggle_mode = true
		btn.button_group = _button_group
		btn.set_meta("archetype_id", archetype_id)
		grid_container.add_child(btn)

	start.disabled = true
	_button_group.pressed.connect(_on_archetype_selected)
	start.pressed.connect(_on_start_pressed)

func _on_archetype_selected(_btn: BaseButton) -> void:
	start.disabled = false

func _on_start_pressed() -> void:
	var pressed := _button_group.get_pressed_button()
	if not pressed:
		return
	var archetype_id: String = pressed.get_meta("archetype_id")
	DeckConfigAL.load_deck_from_file("res://DeckData/" + archetype_id.capitalize() + ".json")
	get_tree().change_scene_to_file(GAME_VIEW)
