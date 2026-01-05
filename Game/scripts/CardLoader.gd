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
	var card_text_started = false
	var card_text_content = []
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# If we've started reading CardText, collect all remaining lines
		if card_text_started:
			card_text_content.append(lines[i])  # Keep original formatting/indentation
			continue
			
		if line.is_empty():
			continue
			
		# Check if this line starts CardText
		if line.begins_with("CardText:"):
			card_text_started = true
			# Get the text after "CardText:" on the same line (if any)
			var first_line = line.substr(9).strip_edges()
			if not first_line.is_empty():
				card_text_content.append(first_line)
			continue
			
		# Parse key:value pairs for non-CardText lines
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
	
	# Set CardText from collected content
	if card_text_content.size() > 0:
		card_data.text_box = "\n".join(card_text_content).strip_edges()
	
	# Parse types and subtypes
	if "Types" in properties:
		var types_text = properties["Types"]
		var type_parts = types_text.split(" ")
		
		# Parse all types (can have multiple types like "Boss Creature")
		for i in range(type_parts.size()):
			var type_part = type_parts[i].strip_edges()
			if CardData.isValidCardTypeString(type_part):
				# Use centralized conversion method
				var card_type = CardData.stringToCardType(type_part)
				card_data.addType(card_type)
			else:
				# If it's not a main type, treat it as a subtype
				if type_part != "" and card_data.subtypes.size() < 3:
					card_data.subtypes.append(type_part)
	
	# Parse abilities
	var abilities = parse_abilities(properties, card_data)
	for ability in abilities:
		if ability:
			card_data.add_ability(ability)
	
	# Parse additional costs
	card_data.additionalCosts = parse_additional_costs(properties)
	
	# Parse spell effects (for spell cards)
	if card_data.hasType(CardData.CardType.SPELL):
		var spell_abilities = parse_spell_effects(properties, card_data)
		for spell_ability in spell_abilities:
			if spell_ability:
				card_data.add_ability(spell_ability)
	
	return card_data

# Parse spell effects from card properties
func parse_spell_effects(properties: Dictionary, card_data: CardData) -> Array[SpellAbility]:
	var spell_effects: Array[SpellAbility] = []
	
	# Look for E: lines (Effect lines for spells)
	for key in properties.keys():
		if key == "E":
			var effect_line = properties[key]
			var spell_ability = parse_single_spell_effect(effect_line, card_data)
			if spell_ability:
				spell_effects.append(spell_ability)
	
	return spell_effects

# Parse a single spell effect line
func parse_single_spell_effect(effect_text: String, card_data: CardData) -> SpellAbility:
	var effect_type_str: String = ""
	var parameters: Dictionary = {}
	
	# Remove the initial "$ " if present
	if effect_text.begins_with("$ "):
		effect_text = effect_text.substr(2)
	
	var parts = effect_text.split(" | ")
	
	for part in parts:
		part = part.strip_edges()
		
		# Parse different effect types
		if part == "DealDamage":
			effect_type_str = "DealDamage"
		elif part == "Pump":
			effect_type_str = "Pump"
		elif part.begins_with("ValidTgts$"):
			parameters["ValidTargets"] = part.substr(11)
		elif part.begins_with("NumDmg$"):
			parameters["NumDamage"] = int(part.substr(8))
		elif part.begins_with("Pow$"):
			parameters["PowerBonus"] = int(part.substr(5))
		elif part.begins_with("Duration$"):
			parameters["Duration"] = part.substr(10)
		# Add more spell effect types as needed (Mill, Draw, Heal, etc.)
	
	if effect_type_str.is_empty():
		return null
	
	# Convert to EffectType enum
	var effect_type = EffectType.string_to_type(effect_type_str)
	
	# Create SpellAbility instance
	var spell_ability = SpellAbility.new(card_data, effect_type)
	spell_ability.effect_parameters = parameters
	
	return spell_ability

# Parse abilities from card properties
func parse_abilities(properties: Dictionary, card_data: CardData) -> Array[CardAbility]:
	var abilities: Array[CardAbility] = []
	var svar_effects: Dictionary = {}
	
	# First pass: collect all SVar definitions
	for key in properties.keys():
		if key == "SVar":
			# Parse the SVar line which has format "SVar:CreateOneMoreToken$ ReplaceToken | Type$ AddToken | Amount$ 1"
			var svar_line = properties[key]
			# Split on $ to get name and definition
			var svar_parts = svar_line.split("$", false, 1)
			if svar_parts.size() >= 2:
				var svar_name = svar_parts[0].strip_edges()
				var svar_definition = svar_parts[1].strip_edges()
				
				# Parse the definition to extract effect type and parameters
				var parsed_svar = _parse_svar_definition(svar_definition)
				svar_effects[svar_name] = parsed_svar
	
	# Second pass: parse triggered abilities and activated abilities
	for key in properties.keys():
		if key == "T":
			var trigger_ability = parse_triggered_ability(properties[key], svar_effects, card_data)
			if trigger_ability:
				abilities.append(trigger_ability)
		elif key == "R":
			var replacement_effect = parse_replacement_effect(properties[key], svar_effects, card_data)
			if replacement_effect:
				abilities.append(replacement_effect)
		elif key == "AA" or key == "A":
			var activated_ability = parse_activated_ability(properties[key], svar_effects, card_data)
			if activated_ability:
				abilities.append(activated_ability)
	
	return abilities

# Parse a single triggered ability
func parse_triggered_ability(trigger_text: String, svar_effects: Dictionary, card_data: CardData) -> TriggeredAbility:
	var trigger_type: TriggerType.Type = TriggerType.Type.CARD_ENTERS
	var trigger_conditions: Dictionary = {}
	var effect_parameters: Dictionary = {}
	var legacy_effect_name: String = ""
	
	var trigger_parts = trigger_text.split(" | ")
	
	# Parse trigger conditions and parameters
	for part in trigger_parts:
		part = part.strip_edges()
		if part.begins_with("Mode$"):
			var mode = part.substr(6)  # Remove "Mode$ "
			trigger_type = TriggerType.string_to_type(mode)
		elif part.begins_with("Origin$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.ORIGIN] = part.substr(8)
		elif part.begins_with("Destination$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.DESTINATION] = part.substr(13)
		elif part.begins_with("ValidCard$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.VALID_CARD] = part.substr(11)
		elif part.begins_with("ValidActivatingPlayer$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.VALID_ACTIVATING_PLAYER] = part.substr(23)
		elif part.begins_with("TriggerZones$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES] = part.substr(14)
		elif part.begins_with("Phase$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.PHASE] = part.substr(7)
		elif part.begins_with("Condition$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.CONDITION] = part.substr(11)
		elif part.begins_with("Execute$"):
			legacy_effect_name = part.substr(9)
	
	# Get effect parameters from SVar
	if legacy_effect_name in svar_effects:
		var svar_data = svar_effects[legacy_effect_name]
		effect_parameters = svar_data.get("parameters", {})
		# Use the effect type from SVar if available
		if not svar_data.get("effect_type", "").is_empty():
			legacy_effect_name = svar_data["effect_type"]
	
	# Set default trigger zone to Battlefield if not specified
	if not trigger_conditions.has(TriggeredAbility.TriggerCondition.TRIGGER_ZONES):
		trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES] = GameZone.parse_trigger_zones("Battlefield")
	else:
		# Convert the string zone to enum array
		var zone_str = trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES]
		trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES] = GameZone.parse_trigger_zones(zone_str)
	
	# Convert trigger type to GameEventType
	var game_event = _convert_trigger_type_to_game_event(trigger_type, trigger_conditions)
	
	# Convert effect name to EffectType
	var effect_type_str = _normalize_effect_name(legacy_effect_name)
	var effect_type = EffectType.string_to_type(effect_type_str)
	
	# Create the TriggeredAbility instance directly
	var ability = TriggeredAbility.new(card_data, game_event, effect_type)
	ability.trigger_conditions = trigger_conditions
	ability.effect_parameters = effect_parameters
	
	return ability

# Helper to convert TriggerType.Type to TriggeredAbility.GameEventType
func _convert_trigger_type_to_game_event(trigger_type: TriggerType.Type, conditions: Dictionary) -> TriggeredAbility.GameEventType:
	"""Convert TriggerType.Type enum to TriggeredAbility.GameEventType"""
	match trigger_type:
		TriggerType.Type.CARD_ENTERS:
			return TriggeredAbility.GameEventType.CARD_ENTERED_PLAY
		TriggerType.Type.CARD_ATTACKS:
			return TriggeredAbility.GameEventType.ATTACK_DECLARED
		TriggerType.Type.CARD_DRAWN:
			return TriggeredAbility.GameEventType.CARD_DRAWN
		TriggerType.Type.PHASE:
			# For phase triggers, check the Phase condition
			var phase = conditions.get(TriggeredAbility.TriggerCondition.PHASE, "")
			match phase:
				"BeginningOfTurn":
					return TriggeredAbility.GameEventType.BEGINNING_OF_TURN
				"EndOfTurn":
					return TriggeredAbility.GameEventType.END_OF_TURN
				_:
					return TriggeredAbility.GameEventType.BEGINNING_OF_TURN  # Default
		_:
			push_warning("Unknown TriggerType: " + str(trigger_type))
			return TriggeredAbility.GameEventType.CARD_ENTERED_PLAY  # Default fallback

# Helper to normalize legacy effect names to modern effect types
func _normalize_effect_name(legacy_name: String) -> String:
	"""Convert legacy effect names (TrigToken, TrigDraw, PlayMe) to modern effect types (CreateToken, Draw, Cast)"""
	match legacy_name:
		"TrigToken":
			return "CreateToken"
		"TrigDraw":
			return "Draw"
		"TrigGrowup":
			return "AddType"
		"Token":
			return "CreateToken"
		"PlayMe":
			return "Cast"
		_:
			# Unknown effect - return as-is and let EffectType.string_to_type handle it
			return legacy_name

# Helper to parse SVar definition into effect type and parameters
func _parse_svar_definition(definition: String) -> Dictionary:
	"""Parse SVar definition like 'ReplaceToken | Type$ AddToken | Amount$ 1' into effect type and parameters"""
	var result = {
		"effect_type": "",
		"parameters": {}
	}
	
	var parts = definition.split(" | ")
	if parts.size() > 0:
		# First part is the effect type (e.g., "ReplaceToken", "Token", "Cast")
		result["effect_type"] = parts[0].strip_edges()
		
		# Remaining parts are parameters
		for i in range(1, parts.size()):
			var part = parts[i].strip_edges()
			if part.begins_with("TokenScript$"):
				result["parameters"]["TokenScript"] = part.substr(13)
			elif part.begins_with("Type$"):
				result["parameters"]["Type"] = part.substr(6)
			elif part.begins_with("Amount$"):
				result["parameters"]["Amount"] = part.substr(8)
			elif part.begins_with("Target$"):
				result["parameters"]["Target"] = part.substr(8)
			elif part.begins_with("Defined$"):
				result["parameters"]["Defined"] = part.substr(9)
			elif part.begins_with("NumCards$"):
				result["parameters"]["NumCards"] = part.substr(10)
			elif part.begins_with("Types$"):
				result["parameters"]["Types"] = part.substr(7)
			elif part.begins_with("Duration$"):
				result["parameters"]["Duration"] = part.substr(10)
	
	return result

# Parse a single replacement effect
func parse_replacement_effect(replacement_text: String, svar_effects: Dictionary, card_data: CardData) -> ReplacementAbility:
	"""
	Parse a replacement effect (R:) that modifies how effects resolve.
	Example: "If one or more Goblin token would be created, create that many plus one instead"
	
	Note: This returns a ReplacementAbility that registers an AbilityModifier
	which intercepts and modifies effects as they resolve.
	"""
	var event_type: String = ""
	var replacement_conditions: Dictionary = {}
	var effect_name: String = ""
	var effect_parameters: Dictionary = {}
	var description: String = ""
	
	var replacement_parts = replacement_text.split(" | ")
	
	# Parse replacement conditions and parameters
	for part in replacement_parts:
		part = part.strip_edges()
		if part.begins_with("Event$"):
			event_type = part.substr(7)  # Remove "Event$ "
		elif part.begins_with("ActiveZones$"):
			replacement_conditions["ActiveZones"] = part.substr(13)
		elif part.begins_with("ValidToken$"):
			replacement_conditions["ValidToken"] = part.substr(12)
		elif part.begins_with("ReplaceWith$"):
			effect_name = part.substr(13)
		elif part.begins_with("Description$"):
			description = part.substr(13)
	
	# Get effect parameters from SVar
	if effect_name in svar_effects:
		var svar_data = svar_effects[effect_name]
		effect_parameters = svar_data.get("parameters", {})
		# Use the effect type from SVar
		if not svar_data.get("effect_type", "").is_empty():
			effect_name = svar_data["effect_type"]
	
	# Convert effect name to EffectType
	var effect_type_str = _normalize_effect_name(effect_name)
	var effect_type = EffectType.string_to_type(effect_type_str)
	
	# Build conditions with event type
	var conditions = replacement_conditions.duplicate()
	conditions["EventType"] = event_type
	
	# Build modifications from effect parameters
	var modifications = effect_parameters.duplicate()
	
	# Create the appropriate ReplacementEffect based on effect type
	var replacement_effect_instance = _create_replacement_effect(card_data, effect_type_str, conditions, modifications)
	if not replacement_effect_instance:
		push_error("Failed to create replacement effect for ", effect_type_str)
		return null
	
	# Create ReplacementAbility instance
	var ability = ReplacementAbility.new(card_data, effect_type, replacement_effect_instance)
	ability.effect_parameters = effect_parameters
	ability.effect_parameters["event_type"] = event_type
	ability.effect_parameters["replacement_conditions"] = replacement_conditions
	ability.effect_parameters["description"] = description
	
	return ability

# Helper to create appropriate ReplacementEffect instance based on effect type
func _create_replacement_effect(owner: CardData, effect_type_str: String, conditions: Dictionary, modifications: Dictionary) -> ReplacementEffect:
	"""Create the appropriate ReplacementEffect subclass based on effect type"""
	var effect: ReplacementEffect = null
	
	match effect_type_str:
		"ReplaceToken":
			effect = ReplaceTokenEffect.new(owner, conditions, modifications)
		_:
			print("⚠️ Unknown replacement effect type: ", effect_type_str)
			return null
	
	# Validate parameters
	if not effect.validate_parameters(modifications):
		print("⚠️ Invalid parameters for ", effect_type_str)
		return null
	
	return effect

# Parse a single activated ability
func parse_activated_ability(activated_text: String, _svar_effects: Dictionary, card_data: CardData) -> ActivatedAbility:
	var effect_type_str: String = ""
	var activation_costs: Array[Dictionary] = []
	var target_conditions: Dictionary = {}
	var effect_parameters: Dictionary = {}
	var description: String = ""
	
	var activated_parts = activated_text.split(" | ")
	
	# Parse activated ability conditions and parameters
	for part in activated_parts:
		part = part.strip_edges()
		if part.begins_with("AB$ "):
			# New format: "AB$ Draw" (e.g., "A:AB$ Draw | Cost$ ...")
			effect_type_str = part.substr(4).strip_edges()
		elif part.begins_with("$ "):
			# Old format: "$ PumpAll" (e.g., "AA:$ PumpAll | Cost$ ...")
			effect_type_str = part.substr(2).strip_edges()
		elif part.begins_with("Cost$"):
			# Parse the cost components (e.g., "Sac.Self+Pay.1" or "{T} Sac<filter>")
			var cost_string = part.substr(6)  # Remove "Cost$ "
			activation_costs = parse_activation_costs(cost_string)
		elif part.begins_with("ValidCards$"):
			target_conditions["ValidCards"] = part.substr(12)
		elif part.begins_with("ValidTargets$"):
			target_conditions["ValidTargets"] = part.substr(14)
		elif part.begins_with("KW$"):
			effect_parameters["KW"] = part.substr(4)
		elif part.begins_with("Duration$"):
			effect_parameters["Duration"] = part.substr(10)
		elif part.begins_with("NumTarget$"):
			effect_parameters["NumTarget"] = part.substr(11)
		elif part.begins_with("NumCards$"):
			effect_parameters["NumCards"] = part.substr(10)
		elif part.begins_with("Amount$"):
			effect_parameters["Amount"] = part.substr(8)
		elif part.begins_with("Description$"):
			description = part.substr(13)
	
	# Convert effect name to EffectType
	var effect_type = EffectType.string_to_type(effect_type_str)
	
	# Create ActivatedAbility instance
	var ability = ActivatedAbility.new(card_data, effect_type)
	ability.activation_costs = activation_costs
	ability.effect_parameters = effect_parameters
	ability.targeting_requirements = target_conditions
	
	return ability

# Parse activation costs from cost string (e.g., "T Sac<1:Card.Creature>" or "Sac.Self+Pay.1")
func parse_activation_costs(cost_string: String) -> Array[Dictionary]:
	var costs: Array[Dictionary] = []
	
	# Parse costs - can be space-separated (new format) or +-separated (old format)
	var cost_parts: Array[String] = []
	
	# Check if this uses the new format with angle brackets
	if "<" in cost_string:
		# New format: parse space-separated costs, but preserve content inside <>
		var temp_parts = cost_string.split(" ", false)
		var i = 0
		while i < temp_parts.size():
			var part = temp_parts[i]
			
			# If this part contains '<', check if it also contains '>'
			if "<" in part:
				if ">" in part:
					# Complete part with both brackets
					cost_parts.append(part.strip_edges())
				else:
					# Incomplete - need to combine with following parts until we find '>'
					var combined = part
					i += 1
					while i < temp_parts.size():
						combined += " " + temp_parts[i]
						if ">" in temp_parts[i]:
							break
						i += 1
					cost_parts.append(combined.strip_edges())
			else:
				# Regular part without brackets
				if not part.strip_edges().is_empty():
					cost_parts.append(part.strip_edges())
			
			i += 1
	else:
		# Old format: parse +-separated costs
		var packed_array = cost_string.split("+")
		for item in packed_array:
			cost_parts.append(item.strip_edges())
	
	for cost_part in cost_parts:
		if cost_part.is_empty():
			continue
		
		var cost_data = {}
		
		# Check for tap cost (new format: T)
		if cost_part == "T":
			cost_data["type"] = "Tap"
			cost_data["target"] = "Self"
		# Check for sacrifice with filter (new format: Sac<count:filter> or Sac<filter>)
		elif cost_part.begins_with("Sac<") and cost_part.ends_with(">"):
			cost_data["type"] = "Sacrifice"
			# Extract the content from between < and >
			var inner_content = cost_part.substr(4, cost_part.length() - 5)
			
			# Check if there's a count prefix (e.g., "1:Card.Creature")
			if ":" in inner_content:
				var parts = inner_content.split(":", false, 1)
				cost_data["count"] = int(parts[0].strip_edges())
				cost_data["target"] = parts[1].strip_edges()
			else:
				# No count specified, default to 1
				cost_data["count"] = 1
				cost_data["target"] = inner_content.strip_edges()
		# Old format sacrifice (Sac.Self)
		elif cost_part.begins_with("Sac."):
			cost_data["type"] = "Sacrifice"
			cost_data["target"] = cost_part.substr(4)  # Remove "Sac."
			cost_data["count"] = 1
		# Old format mana payment (Pay.1)
		elif cost_part.begins_with("Pay."):
			cost_data["type"] = "PayMana"
			cost_data["amount"] = int(cost_part.substr(4))  # Remove "Pay." and convert to int
		# Old format tap (Tap.Self)
		elif cost_part.begins_with("Tap."):
			cost_data["type"] = "Tap"
			cost_data["target"] = cost_part.substr(4)  # Remove "Tap."
		else:
			# Generic cost parsing for future expansion
			cost_data["type"] = "Unknown"
			cost_data["raw"] = cost_part
		
		if not cost_data.is_empty():
			costs.append(cost_data)
	
	return costs

# Parse effect parameters from SVar text
func parse_effect_parameters(effect_text: String) -> Dictionary:
	var parameters: Dictionary = {}
	var parts = effect_text.split(" | ")
	
	for part in parts:
		part = part.strip_edges()
		if part.begins_with("TokenScript$"):
			parameters["TokenScript"] = part.substr(13)
		elif part.begins_with("Defined$"):
			parameters["Defined"] = part.substr(9)
		elif part.begins_with("NumCards$"):
			parameters["NumCards"] = part.substr(10)
		elif part.begins_with("Type$"):
			parameters["Type"] = part.substr(6)
		elif part.begins_with("Amount$"):
			parameters["Amount"] = part.substr(8)
		elif part.begins_with("Target$"):
			parameters["Target"] = part.substr(8)
		elif part.begins_with("Types$"):
			parameters["Types"] = part.substr(7)
		elif part.begins_with("Duration$"):
			parameters["Duration"] = part.substr(10)
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
		
		# Cost types
		if part == "SacrificePermanent" or part == "$ SacrificePermanent":
			cost_data["cost_type"] = "SacrificePermanent"
		elif part == "Replace" or part == "$ Replace":
			cost_data["cost_type"] = "Replace"
		# Parameters
		elif part.begins_with("ValidCard$"):
			cost_data["valid_card"] = part.substr(11)
		elif part.begins_with("ValidCardAlt$"):
			cost_data["valid_card_alt"] = part.substr(14)
		elif part.begins_with("Count "):
			cost_data["count"] = int(part.substr(6))
		elif part.begins_with("MinCount "):
			cost_data["min_count"] = int(part.substr(9))
		elif part.begins_with("AddReduction "):
			cost_data["add_reduction"] = int(part.substr(13))
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
	
	if card_data.hasType(CardData.CardType.LEGENDARY):
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
	
	var copy = [original].duplicate(true)[0]
	return copy

func getCardByName(n: String) -> CardData:
	var f = cardData.filter(func(c:CardData): return c.cardName.to_lower() == n.to_lower())
	if f.size() >0:
		return duplicateCardScript(f[0])
	f = extraDeckCardData.filter(func(c:CardData): return c.cardName.to_lower() == n.to_lower())
	if f.size() >0:
		return duplicateCardScript(f[0])
	f = tokensData.filter(func(c:CardData): return c.cardName.to_lower() == n.to_lower())
	if f.size() >0:
		return duplicateCardScript(f[0])
	f = opponentCards.filter(func(c:CardData): return c.cardName.to_lower() == n.to_lower())
	if f.size() >0:
		return duplicateCardScript(f[0])
	return null
