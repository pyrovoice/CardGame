extends Resource
class_name KeywordData

@export var keyword: String
@export var reminder_text: String

func _init(keyword_name: String = "", text: String = ""):
	keyword = keyword_name
	reminder_text = text
