extends Node
class_name KeywordManager

static var keywords: Dictionary = {}

static func _static_init():
	# Initialize keywords with their reminder text
	initialize_keywords()

static func initialize_keywords():
	keywords["Flying"] = "Flying is a key word with an effect. I'm going to make it very long, just to check that it's well integrate with the rest. Is this long enough? Let's see."
	keywords["Ganking"] = "Ganking is a key word with an effect"
	keywords["Trample"] = "Trample is a key word with an effect"
	keywords["First Strike"] = "First Strike is a key word with an effect"
	keywords["Double Strike"] = "Double Strike is a key word with an effect"
	keywords["Haste"] = "Haste is a key word with an effect"
	keywords["Vigilance"] = "Vigilance is a key word with an effect"
	keywords["Lifelink"] = "Lifelink is a key word with an effect"
	keywords["Deathtouch"] = "Deathtouch is a key word with an effect"
	keywords["Replace"] = "Play on top of another card to reduce my cost by the replaced card's cost."
	keywords["Grown-up"] = "This creature is ready to be replaced! (no direct effect)"
	keywords["Defensive"] = "This creature dies by receiving N additional damages than its might."
	keywords["Offensive"] = "This creature deals N additional damages when attacking."
	keywords["Dustaway"] = "If this card would leave the battlefield, it ceases to exist."
	keywords["Countdown"] = "This card enters with 3 Countdown counter on it. At the beginning of each turn, remove a Countdown counter. When there is no Countdown counter left, sacrifice this card."
	keywords["Elusive"] = "This creature is placed at the end of the combat queue when fighting at a location."
	keywords["Innert"] = "This creature does not attack or block attacks while innert."

static func get_keyword_text(keyword: String) -> String:
	if keywords.has(keyword):
		return keywords[keyword]
	return ""

static func parse_keywords_from_text(card_text: String) -> Array[String]:
	var found_keywords: Array[String] = []
	for keyword in keywords:
		if card_text.contains(keyword):
			found_keywords.append(keyword)
	
	return found_keywords

static func add_keyword(keyword: String, reminder_text: String):
	keywords[keyword] = reminder_text
