extends Node
class_name KeywordManager

static var keywords: Dictionary = {}

static func _static_init():
	# Initialize keywords with their reminder text
	initialize_keywords()

static func initialize_keywords():
	keywords["Flying"] = "Flying is a key word with an effect"
	keywords["Ganking"] = "Ganking is a key word with an effect"
	keywords["Trample"] = "Trample is a key word with an effect"
	keywords["First Strike"] = "First Strike is a key word with an effect"
	keywords["Double Strike"] = "Double Strike is a key word with an effect"
	keywords["Haste"] = "Haste is a key word with an effect"
	keywords["Vigilance"] = "Vigilance is a key word with an effect"
	keywords["Lifelink"] = "Lifelink is a key word with an effect"
	keywords["Deathtouch"] = "Deathtouch is a key word with an effect"

static func get_keyword_text(keyword: String) -> String:
	if keywords.has(keyword):
		return keywords[keyword]
	return ""

static func parse_keywords_from_text(card_text: String) -> Array[String]:
	var found_keywords: Array[String] = []
	
	# Split card text into lines
	var lines = card_text.split("\\n")
	if lines.size() == 0:
		return found_keywords
	
	# Check first line for keywords (assuming keywords are on the first line)
	var first_line = lines[0]
	
	# Split by commas and check each part
	var parts = first_line.split(",")
	for part in parts:
		var trimmed = part.strip_edges()
		if keywords.has(trimmed):
			found_keywords.append(trimmed)
	
	return found_keywords

static func add_keyword(keyword: String, reminder_text: String):
	keywords[keyword] = reminder_text
