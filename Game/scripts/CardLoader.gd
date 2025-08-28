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
	
	# Parse abilities
	card_data.abilities = parse_abilities(properties)
	
	return card_data

# Parse abilities from card properties
static func parse_abilities(properties: Dictionary) -> Array:
	var abilities: Array = []
	var svar_effects: Dictionary = {}
	
	# First pass: collect all SVar definitions
	for key in properties.keys():
		if key.begins_with("SVar:"):
			var effect_name = key.substr(5)  # Remove "SVar:" prefix
			svar_effects[effect_name] = properties[key]
	
	# Second pass: parse trigger abilities
	for key in properties.keys():
		if key.begins_with("T:"):
			var trigger_ability = parse_triggered_ability(properties[key], svar_effects)
			if trigger_ability:
				abilities.append(trigger_ability)
	
	return abilities

# Parse a single triggered ability
static func parse_triggered_ability(trigger_text: String, svar_effects: Dictionary) -> Dictionary:
	var ability_data = {
		"type": "TriggeredAbility",
		"trigger_type": "CHANGES_ZONE",  # Default
		"trigger_conditions": {},
		"effect_name": "",
		"effect_parameters": {},
		"description": ""
	}
	
	var trigger_parts = trigger_text.split(" | ")
	
	# Parse trigger conditions and parameters
	for part in trigger_parts:
		part = part.strip_edges()
		if part.begins_with("Mode$"):
			var mode = part.substr(6)  # Remove "Mode$ "
			# Map mode to trigger type
			match mode:
				"ChangesZone":
					ability_data.trigger_type = "CHANGES_ZONE"
				"CardPlayed":
					ability_data.trigger_type = "CARD_PLAYED"
		elif part.begins_with("Origin$"):
			ability_data.trigger_conditions["Origin"] = part.substr(8)
		elif part.begins_with("Destination$"):
			ability_data.trigger_conditions["Destination"] = part.substr(13)
		elif part.begins_with("ValidCard$"):
			ability_data.trigger_conditions["ValidCard"] = part.substr(11)
		elif part.begins_with("ValidActivatingPlayer$"):
			ability_data.trigger_conditions["ValidActivatingPlayer"] = part.substr(23)
		elif part.begins_with("TriggerZones$"):
			ability_data.trigger_conditions["TriggerZones"] = part.substr(14)
		elif part.begins_with("Execute$"):
			ability_data.effect_name = part.substr(9)
		elif part.begins_with("TriggerDescription$"):
			ability_data.description = part.substr(20)
	
	# Get effect parameters from SVar
	if ability_data.effect_name in svar_effects:
		ability_data.effect_parameters = parse_effect_parameters(svar_effects[ability_data.effect_name])
	else:
		# Try common alternatives for token creation
		if ability_data.effect_name.begins_with("TrigCreate") or ability_data.effect_name.begins_with("Trig"):
			if "TrigToken" in svar_effects:
				ability_data.effect_parameters = parse_effect_parameters(svar_effects["TrigToken"])
				ability_data.effect_name = "TrigToken"  # Normalize the name
	
	return ability_data

# Parse effect parameters from SVar text
static func parse_effect_parameters(effect_text: String) -> Dictionary:
	var parameters: Dictionary = {}
	var parts = effect_text.split(" | ")
	
	for part in parts:
		part = part.strip_edges()
		if part.begins_with("DB$"):
			parameters["DB"] = part.substr(4)
		elif part.begins_with("TokenScript$"):
			parameters["TokenScript"] = part.substr(13)
		# Add more parameter parsing as needed
	
	return parameters

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
	var _file_path = "res://Cards/" + card_name.to_lower().replace(" ", " ") + ".txt"
	return cardData.find(func(c:CardData): return c.cardName == card_name)

static func getRandomCard() -> CardData:
	return cardData[randi_range(0, cardData.size() - 1)]
