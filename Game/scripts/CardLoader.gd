extends RefCounted
class_name CardLoader

static var cardData: Array[CardData] = []
# Parse card data from text content (can be from file or string)
static func parse_card_data(card_text: String) -> CardData:
	var card_data = CardData.new()
	var properties = {}
	
	# Parse the text line by line
	var lines = card_text.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
			
		# Parse key:value pairs
		if ":" in line:
			var parts = line.split(":", false, 1)
			if parts.size() >= 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()
				properties[key] = value
	
	# Set card properties
	if "Name" in properties:
		card_data.cardName = properties["Name"]
	
	if "ManaCost" in properties:
		card_data.cost = int(properties["ManaCost"])
	
	if "Power" in properties:
		card_data.power = int(properties["Power"])
	
	if "CardText" in properties:
		card_data.text_box = properties["CardText"]
	
	# Parse types and subtypes
	if "Types" in properties:
		var types_text = properties["Types"]
		var type_parts = types_text.split(" ")
		
		# First part is the main type
		if type_parts.size() > 0:
			var main_type = type_parts[0].strip_edges()
			if "Creature" in main_type:
				card_data.type = CardData.CardType.CREATURE
			elif "Spell" in main_type:
				card_data.type = CardData.CardType.SPELL
			elif "Permanent" in main_type:
				card_data.type = CardData.CardType.PERMANENT
		
		# Remaining parts are subtypes (up to 3)
		for i in range(1, min(type_parts.size(), 4)):  # Skip first (main type), max 3 subtypes
			var subtype = type_parts[i].strip_edges()
			if subtype != "":
				card_data.subtypes.append(subtype)
	
	return card_data

# Load a card from a text file
static func load_card_from_file(file_path: String) -> CardData:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open file: " + file_path)
		return null
	
	var file_content = file.get_as_text()
	file.close()
	
	return parse_card_data(file_content)

# Load all cards from the Cards directory
static func load_all_cards():
	var dir = DirAccess.open("res://Cards/")
	
	if not dir:
		push_error("Could not open Cards directory")
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".txt") and not dir.current_is_dir():
			var card_data = load_card_from_file("res://Cards/" + file_name)
			if card_data:
				cardData.append(card_data)
		file_name = dir.get_next()

# Load a specific card by name
static func load_card_by_name(card_name: String):
	var file_path = "res://Cards/" + card_name.to_lower().replace(" ", " ") + ".txt"
	return cardData.find(func(c:CardData): return c.cardName == card_name)

static func getRandomCard() -> CardData:
	return cardData[randi_range(0, cardData.size() - 1)]
