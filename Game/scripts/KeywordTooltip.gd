extends Control
class_name KeywordTooltip

@onready var background: Panel = $Background
@onready var keyword_label: Label = $Background/VBoxContainer/KeywordLabel
@onready var description_label: Label = $Background/VBoxContainer/DescriptionLabel

var keyword: String
var description: String

func _ready():
	# Make sure the tooltip is initially hidden
	visible = false

func set_keyword_data(keyword_name: String, keyword_description: String):
	keyword = keyword_name
	description = keyword_description
	
	if keyword_label:
		keyword_label.text = keyword
	if description_label:
		description_label.text = description

func show_tooltip():
	visible = true

func hide_tooltip():
	visible = false

func position_near_point(point: Vector2, offset: Vector2 = Vector2(10, 10)):
	position = point + offset
