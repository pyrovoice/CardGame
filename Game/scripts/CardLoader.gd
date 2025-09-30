extends Node
class_name CardLoader

var cardData: Array[CardData] = []
var extraDeckCardData: Array[CardData] = []
var tokensData: Array[CardData] = []
var opponentCards: Array[CardData] = []

func _ready():
	load_all_cards()
	
# Parse card data from text content (can be from file or string)
func parse_card_data(card_text: String) -> CardData:
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
		card_data.goldCost = int(properties["ManaCost"])
	
	if "Power" in properties:
		card_data.power = int(properties["Power"])
	
	if "CardText" in properties:
		card_data.text_box = properties["CardText"]
	
	# Parse types and subtypes
	if "Types" in properties:
		var types_text = properties["Types"]
		var type_parts = types_text.split(" ")
		
		# Parse all types (can have multiple types like "Boss Creature")
		for i in range(type_parts.size()):
			var type_part = type_parts[i].strip_edges()
			if "Creature" in type_part:
				card_data.addType(CardData.CardType.CREATURE)
			elif "Spell" in type_part:
				card_data.addType(CardData.CardType.SPELL)
			elif "Permanent" in type_part:
				card_data.addType(CardData.CardType.PERMANENT)
			elif "Boss" in type_part:
				card_data.addType(CardData.CardType.BOSS)
			else:
				# If it's not a main type, treat it as a subtype
				if type_part != "" and card_data.subtypes.size() < 3:
					card_data.subtypes.append(type_part)
	
	# Parse abilities
	card_data.abilities = parse_abilities(properties)
	
	# Parse additional costs
	card_data.additionalCosts = parse_additional_costs(properties)
	
	# Parse spell effects (for spell cards)
	if card_data.hasType(CardData.CardType.SPELL):
		var spell_effects = parse_spell_effects(properties)
		if spell_effects.size() > 0:
			card_data.abilities.append_array(spell_effects)
	
	return card_data

# Parse spell effects from card properties
func parse_spell_effects(properties: Dictionary) -> Array[Dictionary]:
	var spell_effects: Array[Dictionary] = []
	
	# Look for E: lines (Effect lines for spells)
	for key in properties.keys():
		if key == "E":
			var effect_line = properties[key]
			var spell_effect = parse_single_spell_effect(effect_line)
			if not spell_effect.is_empty():
				spell_effects.append(spell_effect)
	
	return spell_effects

# Parse a single spell effect line
func parse_single_spell_effect(effect_text: String) -> Dictionary:
	var effect_data = {
		"type": "SpellEffect",
		"effect_type": "",
		"parameters": {},
		"description": ""
	}
	
	# Remove the initial "$ " if present
	if effect_text.begins_with("$ "):
		effect_text = effect_text.substr(2)
	
	var parts = effect_text.split(" | ")
	
	for part in parts:
		part = part.strip_edges()
		
		# Parse different effect types
		if part == "DealDamage":
			effect_data.effect_type = "DealDamage"
		elif part.begins_with("ValidTgts$"):
			effect_data.parameters["ValidTargets"] = part.substr(11)
		elif part.begins_with("NumDmg$"):
			effect_data.parameters["NumDamage"] = int(part.substr(8))
		elif part.begins_with("SpellDescription$"):
			effect_data.description = part.substr(18)
		# Add more spell effect types as needed (Mill, Draw, Heal, etc.)
	
	return effect_data

# Parse abilities from card properties
func parse_abilities(properties: Dictionary) -> Array[Dictionary]:
	var abilities: Array[Dictionary] = []
	var svar_effects: Dictionary = {}
	
	# First pass: collect all SVar definitions
	for key in properties.keys():
		if key == "SVar":
			# Parse the SVar line which has format "TrigToken:DB$ Token | TokenScript$ goblin"
			var svar_line = properties[key]
			# Split on the first colon to get effect name and parameters
			var svar_parts = svar_line.split(":", false, 1)
			if svar_parts.size() >= 2:
				var effect_name = svar_parts[0].strip_edges()
				var effect_value = svar_parts[1].strip_edges()
				svar_effects[effect_name] = effect_value
	
	# Second pass: parse triggered abilities
	for key in properties.keys():
		if key == "T":
			var trigger_ability = parse_triggered_ability(properties[key], svar_effects)
			if trigger_ability:
				abilities.append(trigger_ability)
		elif key == "R":
			var replacement_effect = parse_replacement_effect(properties[key], svar_effects)
			if replacement_effect:
				abilities.append(replacement_effect)
	
	return abilities

# Parse a single triggered ability
func parse_triggered_ability(trigger_text: String, svar_effects: Dictionary) -> Dictionary:
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
			# Use TriggerType enum for consistent mapping
			ability_data.trigger_type = mode  # Store the original string
			# Map mode to trigger type using TriggerType enum
			match mode:
				"ChangesZone":
					ability_data.trigger_type = "CardEnters"  # Map old ChangesZone to CardEnters
				"CardPlayed":
					ability_data.trigger_type = "CardPlayed"
				"CardEnters":
					ability_data.trigger_type = "CardEnters"
				"StartAttack":
					ability_data.trigger_type = "StartAttack"
				"CardDraw":
					ability_data.trigger_type = "CardDraw"
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

# Parse a single replacement effect
func parse_replacement_effect(replacement_text: String, svar_effects: Dictionary) -> Dictionary:
	var ability_data = {
		"type": "ReplacementEffect",
		"event_type": "",  # What event this replaces (e.g., "CreateToken")
		"replacement_conditions": {},
		"effect_name": "",
		"effect_parameters": {},
		"description": ""
	}
	
	var replacement_parts = replacement_text.split(" | ")
	
	# Parse replacement conditions and parameters
	for part in replacement_parts:
		part = part.strip_edges()
		if part.begins_with("Event$"):
			var event_string = part.substr(7)  # Remove "Event$ "
			ability_data.event_type = event_string
		elif part.begins_with("ActiveZones$"):
			ability_data.replacement_conditions["ActiveZones"] = part.substr(13)
		elif part.begins_with("ValidToken$"):
			ability_data.replacement_conditions["ValidToken"] = part.substr(12)
		elif part.begins_with("ReplaceWith$"):
			ability_data.effect_name = part.substr(13)
		elif part.begins_with("Description$"):
			ability_data.description = part.substr(13)
	
	# Get effect parameters from SVar
	if ability_data.effect_name in svar_effects:
		ability_data.effect_parameters = parse_effect_parameters(svar_effects[ability_data.effect_name])
	
	return ability_data

# Parse effect parameters from SVar text
func parse_effect_parameters(effect_text: String) -> Dictionary:
	var parameters: Dictionary = {}
	var parts = effect_text.split(" | ")
	
	for part in parts:
		part = part.strip_edges()
		if part.begins_with("DB$"):
			parameters["DB"] = part.substr(4)
		elif part.begins_with("TokenScript$"):
			parameters["TokenScript"] = part.substr(13)
		elif part.begins_with("Defined$"):
			parameters["Defined"] = part.substr(9)
		elif part.begins_with("NumCards$"):
			parameters["NumCards"] = part.substr(10)
		elif part.begins_with("Type$"):
			parameters["Type"] = part.substr(6)
		elif part.begins_with("Amount$"):
			parameters["Amount"] = part.substr(8)
		# Add more parameter parsing as needed
	
	return parameters

# Parse additional costs from card properties
func parse_additional_costs(properties: Dictionary) -> Array[Dictionary]:
	var additional_costs: Array[Dictionary] = []
	
	# Look for AC$ lines (Additional Cost)
	for key in properties.keys():
		if key == "AC$" or key == "AC":
			var cost_line = properties[key]
			var cost_data = parse_single_additional_cost(cost_line)
			if not cost_data.is_empty():
				additional_costs.append(cost_data)
	
	return additional_costs

# Parse a single additional cost line
func parse_single_additional_cost(cost_text: String) -> Dictionary:
	var cost_data: Dictionary = {}
	var parts = cost_text.split(" | ")
	
	for part in parts:
		part = part.strip_edges()
		
		# Check for exact match first
		if part == "SacrificePermanent":
			cost_data["cost_type"] = "SacrificePermanent"
		elif part == "$ SacrificePermanent":
			cost_data["cost_type"] = "SacrificePermanent"
		elif part.begins_with("SacrificePermanent"):
			cost_data["cost_type"] = "SacrificePermanent"
		elif part.begins_with("ValidCard$"):
			cost_data["valid_card"] = part.substr(11)
		elif part.begins_with("Count "):
			cost_data["count"] = int(part.substr(6))
		elif part.begins_with("MinCount "):
			cost_data["min_count"] = int(part.substr(9))
		# Add more cost types as needed (PayLife, DiscardCard, etc.)
	
	return cost_data

# Load a card from a text file
func load_card_art(card_name: String) -> Texture2D:
	"""Load card art texture for the given card name"""
	var art_path = "res://Assets/CardArts/" + card_name + ".png"
	
	# Check if the file exists
	if ResourceLoader.exists(art_path):
		var texture = load(art_path) as Texture2D
		if texture:
			return texture
	
	return null


func load_card_from_file(file_path: String) -> CardData:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open file: " + file_path)
		return null
	
	var file_content = file.get_as_text()
	file.close()
	
	var card_data = parse_card_data(file_content)
	
	# Extract card name from file path to load corresponding art
	if card_data and card_data.cardName:
		card_data.cardArt = load_card_art(card_data.cardName)
	
	if card_data.hasType(CardData.CardType.BOSS):
		extraDeckCardData.push_back(card_data)
	else:
		cardData.push_back(card_data)
	return card_data

func load_opponent_card_from_file(file_path: String) -> CardData:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open file: " + file_path)
		return null
	
	var file_content = file.get_as_text()
	file.close()
	
	var card_data = parse_card_data(file_content)
	
	# Set opponent controller properties
	if card_data:
		card_data.playerControlled = false
		card_data.playerOwned = false
	
	# Extract card name from file path to load corresponding art
	if card_data and card_data.cardName:
		card_data.cardArt = load_card_art(card_data.cardName)
	
	return card_data

# Load all cards from the Cards/Cards directory
func load_all_cards():
	if cardData.size() > 0:
		cardData = []
		extraDeckCardData = []
		tokensData = []
		opponentCards = []
	# Load regular cards
	var dir = DirAccess.open("res://Cards/Cards/")
	
	if not dir:
		push_error("Could not open Cards/Cards directory")
	else:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Load card files, but skip directories
			if file_name.ends_with(".txt") and not dir.current_is_dir():
				load_card_from_file("res://Cards/Cards/" + file_name)
			file_name = dir.get_next()
	
	# Load tokens
	var token_dir = DirAccess.open("res://Cards/Tokens/")
	
	if not token_dir:
		push_error("Could not open Cards/Tokens directory")
	else:
		token_dir.list_dir_begin()
		var token_file_name = token_dir.get_next()
		
		while token_file_name != "":
			# Load token files, but skip directories
			if token_file_name.ends_with(".txt") and not token_dir.current_is_dir():
				var token_data = load_card_from_file("res://Cards/Tokens/" + token_file_name)
				if token_data:
					tokensData.push_back(token_data)
			token_file_name = token_dir.get_next()
	
	# Load opponent cards
	var opponent_dir = DirAccess.open("res://Cards/OpponentCards/")
	
	if not opponent_dir:
		push_error("Could not open Cards/OpponentCards directory")
	else:
		opponent_dir.list_dir_begin()
		var opponent_file_name = opponent_dir.get_next()
		
		while opponent_file_name != "":
			# Load opponent card files, but skip directories
			if opponent_file_name.ends_with(".txt") and not opponent_dir.current_is_dir():
				var opponent_card = load_opponent_card_from_file("res://Cards/OpponentCards/" + opponent_file_name)
				if opponent_card:
					opponentCards.push_back(opponent_card)
			opponent_file_name = opponent_dir.get_next()
		
		print("Loaded ", opponentCards.size(), " opponent cards")

# Load a specific card by name
func load_card_by_name(card_name: String) -> CardData:
	var filter = cardData.filter(func(c:CardData): return c.cardName == card_name)
	if filter.size() >= 1:
		return filter[0]
	return null

# Load a specific token by name
func load_token_by_name(token_name: String) -> CardData:
	var filter = tokensData.filter(func(c:CardData): return c.cardName.contains(token_name))
	if filter.size() >= 1:
		return filter[0]
	return null

# Load a specific opponent card by name
func load_opponent_card_by_name(opponent_name: String) -> CardData:
	var filter = opponentCards.filter(func(c:CardData): return c.cardName == opponent_name)
	if filter.size() >= 1:
		return filter[0]
	return null

# Get a random opponent card
func getRandomOpponentCard() -> CardData:
	if opponentCards.size() > 0:
		return opponentCards[randi_range(0, opponentCards.size() - 1)]
	return null

func getRandomCard() -> CardData:
	return cardData[randi_range(0, cardData.size() - 1)]

# Custom deep copy method for CardData objects to replace broken duplicate() method
func duplicateCardScript(original: CardData) -> CardData:
	if not original:
		return null
	
	var copy = CardData.new()
	
	# Copy simple properties
	copy.cardName = original.cardName
	copy.goldCost = original.goldCost
	copy.power = original.power
	copy.text_box = original.text_box
	copy.cardArt = original.cardArt
	copy.playerControlled = original.playerControlled
	copy.playerOwned = original.playerOwned
	
	# Deep copy arrays by manually copying each element
	copy.types = []
	for card_type in original.types:
		copy.types.append(card_type)
	
	copy.subtypes = []
	for subtype in original.subtypes:
		copy.subtypes.append(subtype)
	
	copy.abilities = []
	for ability in original.abilities:
		copy.abilities.append(ability)
	
	copy.additionalCosts = []
	for additional_cost in original.additionalCosts:
		# Deep copy dictionaries manually
		var cost_copy = {}
		for key in additional_cost:
			cost_copy[key] = additional_cost[key]
		copy.additionalCosts.append(cost_copy)
	
	return copy
