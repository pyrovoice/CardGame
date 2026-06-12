extends Control
class_name CardChoicePicker

signal choice_made(index: int)  # -1 = skipped

@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var background: ColorRect = $ColorRect

var _items: Array = []
var _dismissible: bool = false

func _ready():
	for card2d in h_box_container.get_children():
		(card2d as Card2D).card_clicked.connect(_on_card_clicked)
		card2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.gui_input.connect(_on_background_input)
	hide()

func show_choices(items: Array, dismissible: bool = false) -> void:
	assert(items.size() >= 1 and items.size() <= 3, "CardChoicePicker expects 1–3 items")
	_items = items
	_dismissible = dismissible
	var cards = h_box_container.get_children()
	for i in 3:
		var card2d := cards[i] as Card2D
		if i < items.size():
			var item = items[i]
			if item is CardData:
				card2d.set_card(item)
			else:
				var data := CardData.new()
				data.cardName = item.get("title", "")
				data.text_box = item.get("text", "")
				card2d.set_card(data)
			card2d.set_selectable(true)
			card2d.visible = true
		else:
			card2d.visible = false
	show()

func skip() -> void:
	_dismiss(-1)

func _on_background_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and _dismissible:
		_dismiss(-1)

func _on_card_clicked(card2d: Card2D) -> void:
	var index := h_box_container.get_children().find(card2d)
	if index >= 0 and index < _items.size():
		_dismiss(index)

func _dismiss(index: int) -> void:
	_items = []
	_dismissible = false
	choice_made.emit(index)
	hide()
