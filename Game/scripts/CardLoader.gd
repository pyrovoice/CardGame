extends Node
class_name CardLoader

enum Archetype {
	UNKNOWN,
	PUNGLYND,
	NECROMANCER,
	# Add more archetypes as new folders are created
}

var cardData: Array[CardData] = []
var extraDeckCardData: Array[CardData] = []
var tokensData: Array[CardData] = []
var opponentCards: Array[CardData] = []

# Dictionary mapping Archetype enum to Array[CardData]
var archetype_pools: Dictionary = {}

# Second-pass cross-reference resolution
enum ResolutionReason {
	PREPARED_SPELL,
	# TRANSFORM_INTO,
	# CREATES_NAMED_CARD,
}
var pending_resolutions: Array[Dictionary] = []

func _ready():
	# Initialize archetype pools with properly typed arrays
	for archetype in Archetype.values():
		var pool: Array[CardData] = []
		archetype_pools[archetype] = pool
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
				
				# Handle keys that can have multiple values (store as array)
				if key in ["SVar", "T", "R", "AA", "A", "K", "E"]:
					if not properties.has(key):
						properties[key] = []
					properties[key].append(value)
				else:
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
				if type_part != "" and card_data._subtypes.size() < 3:
					card_data.addSubtype(type_part)
	
	# Parse abilities
	var abilities = parse_abilities(properties, card_data)
	for ability in abilities:
		if ability:
			card_data.add_ability(ability)
	
	# Add automatic triggered abilities for special keywords
	_add_keyword_triggered_abilities(card_data)
	
	# Parse additional costs
	card_data.additionalCosts = parse_additional_costs(properties)
	
	# Parse casting conditions
	card_data.castingConditions = parse_casting_conditions(properties)
	
	# Parse spell effects (for spell cards)
	if card_data.hasType(CardData.CardType.SPELL):
		card_data.spell_effects = parse_spell_effects(properties, card_data)
	
	# Register cross-references that need a second pass
	if "PreparedSpell" in properties:
		pending_resolutions.append({
			"card": card_data,
			"reason": ResolutionReason.PREPARED_SPELL,
			"ref_name": properties["PreparedSpell"]
		})
	
	return card_data

# Parse spell effects from card properties
func parse_spell_effects(properties: Dictionary, card_data: CardData) -> Array[Dictionary]:
	var spell_effects: Array[Dictionary] = []
	
	# Look for E: lines (Effect lines for spells)
	if properties.has("E"):
		var effect_lines = properties["E"]
		# Handle both single string and array of strings
		if typeof(effect_lines) == TYPE_STRING:
			effect_lines = [effect_lines]
		
		for effect_line in effect_lines:
			var effect_dict = parse_single_spell_effect(effect_line, card_data)
			if effect_dict:
				spell_effects.append(effect_dict)
	
	return spell_effects

# Parse a single spell effect line (same parsing as triggered abilities)
func parse_single_spell_effect(effect_text: String, card_data: CardData) -> Dictionary:
	var effect_type_str: String = ""
	
	# Remove the initial "$ " if present
	if effect_text.begins_with("$ "):
		effect_text = effect_text.substr(2)
	
	var parts = effect_text.split(" | ")
	
	# First pass: detect effect type
	for part in parts:
		part = part.strip_edges()
		
		# Check if this part matches any valid effect type
		if part in ["CreateDelayedEffect", "DealDamage", "Pump", "Draw", "CreateToken", 
					"CreateCard", "Cast", "AddType", "AddKeyword", "PumpAll", "MoveCard", 
					"SwitchPositions", "Destroy", "Bounce", "Exile", "Mill", "Discard", 
					"Search", "Shuffle", "Sacrifice"]:
			effect_type_str = part
			break
	
	# Special handling for CreateDelayedEffect - parse nested effect at load time
	if effect_type_str == "CreateDelayedEffect":
		return _parse_create_delayed_effect_dict(parts, card_data)
	
	# Standard effect parsing - use shared parameter parser
	var parameters = _parse_effect_parameters_from_parts(parts)
	
	if effect_type_str.is_empty():
		return {}
	
	# Validate effect type before converting
	if not _is_valid_effect_type(effect_type_str):
		push_error("❌ [CARD LOAD ERROR] Invalid effect type '" + effect_type_str + "' in spell effect for card: " + card_data.cardName)
		push_error("   Valid types: DealDamage, Pump, Draw, CreateToken, CreateCard, Cast, AddType, AddKeyword, MoveCard, SwitchPositions, etc.")
		return {}
	
	# Convert to EffectType enum
	var effect_type = EffectType.string_to_type(effect_type_str)
	
	# Return simple dictionary with effect type and parameters
	return {
		"effect_type": effect_type,
		"effect_parameters": parameters
	}

# Shared helper to parse effect parameters from parts array
func _parse_effect_parameters_from_parts(parts: Array) -> Dictionary:
	"""Extract effect parameters from parts array (shared between spell effects and nested effects)"""
	var parameters: Dictionary = {}
	
	for part in parts:
		part = part.strip_edges()
		
		# Common parameters
		if part.begins_with("ValidTgts$"):
			parameters["ValidTargets"] = part.substr(11)
		elif part.begins_with("ValidCards$"):
			parameters["ValidCards"] = part.substr(12)
		elif part.begins_with("ValidCard$"):
			parameters["ValidCard"] = part.substr(11)
		elif part.begins_with("Num$"):
			parameters["Num"] = part.substr(5)
		elif part.begins_with("NumCard$"):
			parameters["NumCard"] = int(part.substr(8))
		elif part.begins_with("NumDmg$"):
			parameters["NumDamage"] = int(part.substr(8))
		elif part.begins_with("Pow$"):
			parameters["PowerBonus"] = int(part.substr(5))
		elif part.begins_with("Defined$"):
			parameters["Defined"] = part.substr(9)
		elif part.begins_with("Duration$"):
			parameters["Duration"] = part.substr(10)
		elif part.begins_with("Origin$"):
			parameters["Origin"] = part.substr(8)
		elif part.begins_with("Destination$"):
			parameters["Destination"] = part.substr(13)
		elif part.begins_with("Choice$"):
			parameters["Choice"] = part.substr(8)
		elif part.begins_with("Condition$"):
			parameters["Condition"] = part.substr(11)
		elif part.begins_with("IfNotFound$"):
			parameters["IfNotFound"] = part.substr(12)
		# Add more parameter types as needed
	
	return parameters

# Helper to parse CreateDelayedEffect for spell effects (returns Dictionary)
func _parse_create_delayed_effect_dict(parts: Array, card_data: CardData) -> Dictionary:
	var trigger_event_str: String = ""
	var nested_effect_str: String = ""
	
	# Parse CreateDelayedEffect-specific parameters
	for part in parts:
		part = part.strip_edges()
		
		if part.begins_with("TriggerEvent$"):
			trigger_event_str = part.substr(14)
		elif part.begins_with("Effect$"):
			nested_effect_str = part.substr(8)
	
	# Parse nested effect parameters using shared parser (filters out TriggerEvent$ and Effect$)
	var nested_parameters = _parse_effect_parameters_from_parts(parts)
	
	if nested_effect_str.is_empty():
		push_error("❌ [CARD LOAD ERROR] CreateDelayedEffect requires Effect$ parameter for card: " + card_data.cardName)
		return {}
	
	# Validate nested effect type
	if not _is_valid_effect_type(nested_effect_str):
		push_error("❌ [CARD LOAD ERROR] Invalid nested effect type '" + nested_effect_str + "' in CreateDelayedEffect for card: " + card_data.cardName)
		return {}
	
	# Parse trigger event to GameEventType
	var trigger_event = parse_game_event_from_string(trigger_event_str)
	
	# Convert nested effect string to EffectType
	var nested_effect_type = EffectType.string_to_type(nested_effect_str)
	
	# Store pre-parsed data in parameters
	var parameters: Dictionary = {
		"TriggerEvent": trigger_event,  # GameEventType enum (pre-parsed)
		"NestedEffectType": nested_effect_type,  # EffectType enum (pre-parsed)
		"NestedParameters": nested_parameters  # Parameters for nested effect
	}
	
	# Return dictionary with effect type and parameters
	var effect_type = EffectType.string_to_type("CreateDelayedEffect")
	return {
		"effect_type": effect_type,
		"effect_parameters": parameters
	}

# Parse abilities from card properties
func parse_abilities(properties: Dictionary, card_data: CardData) -> Array[CardAbility]:
	var abilities: Array[CardAbility] = []
	var svar_effects: Dictionary = {}
	
	# First pass: collect all SVar definitions
	if properties.has("SVar"):
		var svar_lines = properties["SVar"]
		# Handle both single string and array of strings
		if typeof(svar_lines) == TYPE_STRING:
			svar_lines = [svar_lines]
		
		for svar_line in svar_lines:
			# Parse the SVar line which has format "SVar:CreateOneMoreToken$ ReplaceToken | Type$ AddToken | Amount$ 1"
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
			var trigger_lines = properties[key]
			# Handle both single string and array of strings
			if typeof(trigger_lines) == TYPE_STRING:
				trigger_lines = [trigger_lines]
			
			for trigger_line in trigger_lines:
				var trigger_abilities = _parse_multiple_triggered_abilities(trigger_line, svar_effects, card_data)
				for trigger_ability in trigger_abilities:
					if trigger_ability:
						abilities.append(trigger_ability)
		elif key == "R":
			var replacement_lines = properties[key]
			# Handle both single string and array of strings
			if typeof(replacement_lines) == TYPE_STRING:
				replacement_lines = [replacement_lines]
			
			for replacement_line in replacement_lines:
				var replacement_effect = parse_replacement_effect(replacement_line, svar_effects, card_data)
				if replacement_effect:
					abilities.append(replacement_effect)
		elif key == "AA" or key == "A":
			var activated_lines = properties[key]
			# Handle both single string and array of strings
			if typeof(activated_lines) == TYPE_STRING:
				activated_lines = [activated_lines]
			
			for activated_line in activated_lines:
				var activated_ability = parse_activated_ability(activated_line, svar_effects, card_data)
				if activated_ability:
					abilities.append(activated_ability)
	
	return abilities

# Helper to parse triggered abilities that may have multiple effects
func _parse_multiple_triggered_abilities(trigger_text: String, svar_effects: Dictionary, card_data: CardData) -> Array[TriggeredAbility]:
	"""Parse a trigger that may have multiple Execute$ effects separated by &"""
	var abilities: Array[TriggeredAbility] = []
	
	# First, parse the base trigger to extract the Execute$ part
	var execute_effects: Array[String] = []
	var base_trigger = trigger_text
	
	# Look for Execute$ in the trigger text
	if " Execute$ " in trigger_text or "|Execute$" in trigger_text:
		var parts = trigger_text.split(" | ")
		for i in range(parts.size()):
			var part = parts[i].strip_edges()
			if part.begins_with("Execute$"):
				# Extract the effect names (may be multiple separated by &)
				var effect_names_str = part.substr(9)  # Remove "Execute$ "
				
				# Split by & if there are multiple effects
				if "&" in effect_names_str:
					var effect_names = effect_names_str.split("&")
					for effect_name in effect_names:
						execute_effects.append(effect_name.strip_edges())
				else:
					execute_effects.append(effect_names_str.strip_edges())
				
				# Create base trigger without Execute$ for reuse
				var base_parts = parts.duplicate()
				base_parts.remove_at(i)
				base_trigger = " | ".join(base_parts)
				break
	
	# If no effects found, return empty array
	if execute_effects.is_empty():
		return abilities
	
	# Create a triggered ability for each effect
	for effect_name in execute_effects:
		# Reconstruct trigger with single Execute$
		var single_trigger = base_trigger + " | Execute$ " + effect_name
		var ability = parse_triggered_ability(single_trigger, svar_effects, card_data)
		if ability:
			abilities.append(ability)
	
	return abilities

# Parse a single triggered ability
func parse_triggered_ability(trigger_text: String, svar_effects: Dictionary, card_data: CardData) -> TriggeredAbility:
	var trigger_type: TriggerType.Type = TriggerType.Type.CARD_ENTERS
	var trigger_conditions: Dictionary = {}
	var effect_parameters: Dictionary = {}
	var effect_name: String = ""
	
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
			trigger_conditions[TriggeredAbility.TriggerCondition.PHASE] = part.substr(7).strip_edges()
		elif part.begins_with("Condition$"):
			trigger_conditions[TriggeredAbility.TriggerCondition.CONDITION] = part.substr(11)
		elif part.begins_with("Execute$"):
			effect_name = part.substr(9)
	
	# Get effect parameters from SVar
	if effect_name in svar_effects:
		var svar_data = svar_effects[effect_name]
		effect_parameters = svar_data.get("parameters", {})
		# Use the effect type from SVar if available
		if not svar_data.get("effect_type", "").is_empty():
			effect_name = svar_data["effect_type"]
	
	# Set default trigger zone to Battlefield if not specified
	if not trigger_conditions.has(TriggeredAbility.TriggerCondition.TRIGGER_ZONES):
		trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES] = GameZone.parse_trigger_zones("Battlefield")
	else:
		# Convert the string zone to enum array
		var zone_str = trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES]
		trigger_conditions[TriggeredAbility.TriggerCondition.TRIGGER_ZONES] = GameZone.parse_trigger_zones(zone_str)
	
	# Convert trigger type to GameEventType
	var game_event = _convert_trigger_type_to_game_event(trigger_type, trigger_conditions)
	
	# Validate effect name before converting
	if not _is_valid_effect_type(effect_name):
		push_error("❌ [CARD LOAD ERROR] Invalid effect type '" + effect_name + "' in triggered ability for card: " + card_data.cardName)
		push_error("   Valid types: DealDamage, Pump, Draw, CreateToken, CreateCard, Cast, AddType, AddKeyword, MoveCard, SwitchPositions, etc.")
		return null
	
	# Convert effect name to EffectType
	var effect_type = EffectType.string_to_type(effect_name)
	
	# Create the TriggeredAbility instance directly
	var ability = TriggeredAbility.new(card_data, game_event, effect_type)
	ability.trigger_conditions = trigger_conditions
	ability.effect_parameters = effect_parameters
	
	return ability

# Helper to parse game event directly from string (for delayed effects)
func parse_game_event_from_string(event_str: String) -> TriggeredAbility.GameEventType:
	"""Convert trigger event string to GameEventType enum (e.g., 'EndOfTurn' -> END_OF_TURN)"""
	match event_str:
		"EndOfTurn":
			return TriggeredAbility.GameEventType.END_OF_TURN
		"BeginningOfTurn":
			return TriggeredAbility.GameEventType.BEGINNING_OF_TURN
		"CardDrawn":
			return TriggeredAbility.GameEventType.CARD_DRAWN
		"EndOfCombat":
			# Note: No EndOfCombat event yet - fallback to EndOfTurn
			push_warning("EndOfCombat not implemented, using EndOfTurn")
			return TriggeredAbility.GameEventType.END_OF_TURN
		_:
			push_warning("Unknown trigger event: " + event_str + ", defaulting to EndOfTurn")
			return TriggeredAbility.GameEventType.END_OF_TURN

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
		TriggerType.Type.CHANGED_ZONE:
			return TriggeredAbility.GameEventType.CARD_CHANGED_ZONES
		TriggerType.Type.PHASE:
			# For phase triggers, check the Phase condition
			var phase = conditions.get(TriggeredAbility.TriggerCondition.PHASE, "")
			# Use the new helper function
			return parse_game_event_from_string(phase)
		TriggerType.Type.STRIKE:
			return TriggeredAbility.GameEventType.STRIKE
		_:
			push_warning("Unknown TriggerType: " + str(trigger_type))
			return TriggeredAbility.GameEventType.CARD_ENTERED_PLAY  # Default fallback

# Add automatic triggered abilities for special keywords
func _add_keyword_triggered_abilities(card_data: CardData):
	"""Add triggered abilities for keywords that require special game logic"""
	# Check if card has Elusive keyword
	if card_data.text_box.contains("Elusive"):
		_add_elusive_ability(card_data)
	
	# Check if card has fleeting keyword (case-insensitive)
	if card_data.has_keyword("fleeting"):
		_add_fleeting_ability(card_data)

# Add the Elusive triggered ability
func _add_elusive_ability(card_data: CardData):
	"""Add automatic triggered ability for Elusive keyword
	
	Elusive triggers when:
	- Combat starts (attack is declared at a combat zone)
	- The Elusive card is in that combat zone
	- There are other cards in the same zone
	Effect: Move to the last position in the combat zone
	"""
	# Parse as a standard triggered ability string
	# Using StartAttack (ATTACK_DECLARED) trigger instead of ChangedZone
	# ValidCard$ Card.Self makes it trigger only when this card attacks (once per combat)
	var trigger_string = "Mode$ StartAttack | ValidCard$ Card.Self | TriggerZones$ Combat | Execute$ ElusiveRetreat"
	
	# Create SVar for the effect
	var svar_effects = {
		"ElusiveRetreat": {
			"effect_type": "SwitchPositions",
			"parameters": {
				"SwitchWith": "LastOther",  # Swap with the last card in zone (that isn't self)
				"OnlySameLocation": true
			}
		}
	}
	
	var ability = parse_triggered_ability(trigger_string, svar_effects, card_data)
	if ability:
		card_data.add_ability(ability)

# Add the fleeting triggered ability
func _add_fleeting_ability(card_data: CardData):
	"""Add automatic triggered ability for fleeting keyword
	
	Fleeting triggers when:
	- Turn ends
	- The fleeting card is in hand
	Effect: Move to graveyard (discard)
	"""
	# Parse as a standard triggered ability string
	# Mode$ Phase trigger on EndOfTurn
	# TriggerZones$ Hand - only triggers when in hand
	var trigger_string = "Mode$ Phase | Phase$ EndOfTurn | TriggerZones$ Hand | Execute$ FleetingDiscard"
	
	# Create SVar for the effect
	var svar_effects = {
		"FleetingDiscard": {
			"effect_type": "MoveCard",
			"parameters": {
				"Origin": "Hand.Controller",
				"Destination": "Graveyard.Controller",
				"Defined": "Self"
			}
		}
	}
	
	var ability = parse_triggered_ability(trigger_string, svar_effects, card_data)
	if ability:
		card_data.add_ability(ability)

# Validate if an effect type string is valid
func _is_valid_effect_type(effect_type_str: String) -> bool:
	"""Check if an effect type string is recognized by EffectType enum"""
	var valid_types = [
		"DealDamage", "Pump", "Draw", "CreateToken", "CreateCard", "Cast",
		"AddType", "AddKeyword", "PumpAll", "MoveCard", "SwitchPositions",
		"Destroy", "Bounce", "Exile", "Mill", "Discard", "Search", "Shuffle",
		"Sacrifice", "CreateDelayedEffect"
	]
	return effect_type_str.strip_edges() in valid_types

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
			elif part.begins_with("Num$"):
				result["parameters"]["Num"] = part.substr(5)
			elif part.begins_with("Pool$"):
				result["parameters"]["Pool"] = part.substr(6)
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
			# MoveCard effect parameters
			elif part.begins_with("Origin$"):
				result["parameters"]["Origin"] = part.substr(8)
			elif part.begins_with("Destination$"):
				result["parameters"]["Destination"] = part.substr(13)
			elif part.begins_with("Choice$"):
				result["parameters"]["Choice"] = part.substr(8)
			elif part.begins_with("ValidCard$"):
				result["parameters"]["ValidCard"] = part.substr(11)
			elif part.begins_with("Condition$"):
				result["parameters"]["Condition"] = part.substr(11)
			elif part.begins_with("IfNotFound$"):
				result["parameters"]["IfNotFound"] = part.substr(12)
			elif part.begins_with("Modif$"):
				result["parameters"]["Modif"] = part.substr(7)
	
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
	
	# Validate event type before converting
	if not _is_valid_effect_type(event_type):
		push_error("❌ [CARD LOAD ERROR] Invalid event type '" + event_type + "' in replacement effect for card: " + card_data.cardName)
		push_error("   Valid types: DealDamage, Pump, Draw, CreateToken, CreateCard, Cast, AddType, AddKeyword, MoveCard, SwitchPositions, etc.")
		return null
	
	# Replacement abilities are keyed by the event they replace (e.g., CreateToken).
	var effect_type = EffectType.string_to_type(event_type)
	
	# Build conditions with event type
	var conditions = replacement_conditions.duplicate()
	conditions["EventType"] = event_type
	
	# Build modifications from effect parameters
	var modifications = effect_parameters.duplicate()
	
	# Create the appropriate ReplacementEffect based on effect type
	var replacement_effect_instance = _create_replacement_effect(card_data, effect_name, conditions, modifications)
	if not replacement_effect_instance:
		push_error("Failed to create replacement effect for ", effect_name)
		return null
	
	# Create ReplacementAbility instance
	var ability = ReplacementAbility.new(card_data, effect_type, replacement_effect_instance)
	ability.effect_parameters = effect_parameters
	ability.effect_parameters["event_type"] = event_type
	ability.effect_parameters["replacement_conditions"] = replacement_conditions
	ability.effect_parameters["description"] = description
	
	return ability

# Helper to create appropriate ReplacementEffect instance based on effect type
func _create_replacement_effect(source: CardData, effect_type_str: String, conditions: Dictionary, modifications: Dictionary) -> ReplacementEffect:
	"""Create the appropriate ReplacementEffect subclass based on effect type"""
	var effect: ReplacementEffect = null
	
	match effect_type_str:
		"ReplaceToken":
			effect = ReplaceTokenEffect.new(source, conditions, modifications)
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
	
	# Validate effect type before converting
	if effect_type_str.is_empty():
		push_error("❌ [CARD LOAD ERROR] No effect type specified in activated ability for card: " + card_data.cardName)
		return null
	
	if not _is_valid_effect_type(effect_type_str):
		push_error("❌ [CARD LOAD ERROR] Invalid effect type '" + effect_type_str + "' in activated ability for card: " + card_data.cardName)
		push_error("   Valid types: DealDamage, Pump, Draw, CreateToken, CreateCard, Cast, AddType, AddKeyword, MoveCard, SwitchPositions, etc.")
		return null
	
	# Convert effect name to EffectType
	var effect_type = EffectType.string_to_type(effect_type_str)
	
	# Create ActivatedAbility instance
	var ability = ActivatedAbility.new(card_data, effect_type)
	ability.activation_costs = activation_costs
	ability.effect_parameters = effect_parameters
	ability.targeting_requirements = target_conditions
	ability.description = description
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
		elif part.begins_with("Num$"):
			parameters["Num"] = part.substr(5)
		elif part.begins_with("Pool$"):
			parameters["Pool"] = part.substr(6)
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
		elif part.begins_with("Modif$"):
			parameters["Modif"] = part.substr(7)
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

# Parse casting conditions from card properties
func parse_casting_conditions(properties: Dictionary) -> Array[String]:
	var casting_conditions: Array[String] = []
	
	# Look for CC$ lines (Casting Condition)
	for key in properties.keys():
		if key == "CC$" or key == "CC":
			var condition_line = properties[key]
			# Handle both single string and array of strings
			if typeof(condition_line) == TYPE_STRING:
				# Remove "$ " prefix if present
				if condition_line.begins_with("$ "):
					condition_line = condition_line.substr(2)
				casting_conditions.append(condition_line.strip_edges())
			else:
				for condition in condition_line:
					if condition.begins_with("$ "):
						condition = condition.substr(2)
					casting_conditions.append(condition.strip_edges())
	
	return casting_conditions

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


func load_card_from_file(file_path: String, archetype: Archetype = Archetype.UNKNOWN) -> CardData:
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
	
	# Add to archetype pool
	if archetype != Archetype.UNKNOWN:
		archetype_pools[archetype].append(card_data)
	
	if card_data.hasType(CardData.CardType.LEGENDARY):
		extraDeckCardData.push_back(card_data)
	else:
		cardData.push_back(card_data)
	return card_data

func load_token_from_file(file_path: String, archetype: Archetype = Archetype.UNKNOWN) -> CardData:
	"""Load a token card file - tokens are NOT added to cardData/extraDeckCardData"""
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
	
	# Add to archetype pool
	if archetype != Archetype.UNKNOWN:
		archetype_pools[archetype].append(card_data)
	
	return card_data

func load_opponent_card_from_file(file_path: String, archetype: Archetype = Archetype.UNKNOWN) -> CardData:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open file: " + file_path)
		return null
	
	var file_content = file.get_as_text()
	file.close()
	
	var card_data = parse_card_data(file_content)
	
	# Set opponent ownership property
	if card_data:
		card_data.playerOwned = false
		
		# Add to archetype pool
		if archetype != Archetype.UNKNOWN:
			archetype_pools[archetype].append(card_data)
	
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
		pending_resolutions = []
	# Load regular cards (recursively supports subdirectories)
	var dir = DirAccess.open("res://Cards/Cards/")
	
	if not dir:
		push_error("Could not open Cards/Cards directory")
	else:
		_load_cards_from_directory_recursive("res://Cards/Cards/", dir, false, "res://Cards/Cards")
		print("Loaded ", cardData.size() + extraDeckCardData.size(), " regular cards")
	
	# Load tokens (recursively supports subdirectories)
	var token_dir = DirAccess.open("res://Cards/Tokens/")
	
	if not token_dir:
		push_error("Could not open Cards/Tokens directory")
	else:
		# Tokens need special handling since they go in tokensData array
		token_dir.list_dir_begin()
		var token_file_name = token_dir.get_next()
		
		while token_file_name != "":
			var full_path = "res://Cards/Tokens/" + token_file_name
			
			if token_dir.current_is_dir():
				# Skip special directories
				if token_file_name != "." and token_file_name != "..":
					# Recursively search token subdirectories
					var sub_dir = DirAccess.open(full_path)
					if sub_dir:
						_load_tokens_from_directory_recursive(full_path, sub_dir)
			elif token_file_name.ends_with(".txt"):
				# Extract archetype from folder structure
				var archetype = _extract_archetype_from_path(full_path, "res://Cards/Tokens")
				
				var token_data = load_token_from_file(full_path, archetype)
				if token_data:
					tokensData.push_back(token_data)
			
			token_file_name = token_dir.get_next()
		
		print("Loaded ", tokensData.size(), " tokens")
	
	# Load opponent cards
	var opponent_dir = DirAccess.open("res://Cards/OpponentCards/")
	
	if not opponent_dir:
		push_error("Could not open Cards/OpponentCards directory")
	else:
		_load_cards_from_directory_recursive("res://Cards/OpponentCards/", opponent_dir, true, "res://Cards/OpponentCards")
		print("Loaded ", opponentCards.size(), " opponent cards")
	
	# Second pass: resolve cross-references between cards
	_resolve_pending_references()
	
	# Print archetype pool summary
	for archetype in Archetype.values():
		var pool_size = archetype_pools[archetype].size()
		if pool_size > 0:
			print("Archetype ", Archetype.keys()[archetype], ": ", pool_size, " cards")

func _load_cards_from_directory_recursive(base_path: String, dir: DirAccess, is_opponent: bool = false, root_path: String = ""):
	"""Recursively load card files from a directory and its subdirectories"""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = base_path + "/" + file_name
		
		if dir.current_is_dir():
			# Skip special directories
			if file_name != "." and file_name != "..":
				# Recursively search subdirectories
				var sub_dir = DirAccess.open(full_path)
				if sub_dir:
					_load_cards_from_directory_recursive(full_path, sub_dir, is_opponent, root_path)
		elif file_name.ends_with(".txt"):
			# Extract archetype from folder structure
			var archetype = _extract_archetype_from_path(full_path, root_path)
			
			# Load card file
			if is_opponent:
				var opponent_card = load_opponent_card_from_file(full_path, archetype)
				if opponent_card:
					opponentCards.push_back(opponent_card)
			else:
				load_card_from_file(full_path, archetype)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _load_tokens_from_directory_recursive(base_path: String, dir: DirAccess):
	"""Recursively load token files from a directory and its subdirectories"""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = base_path + "/" + file_name
		
		if dir.current_is_dir():
			# Skip special directories
			if file_name != "." and file_name != "..":
				# Recursively search subdirectories
				var sub_dir = DirAccess.open(full_path)
				if sub_dir:
					_load_tokens_from_directory_recursive(full_path, sub_dir)
		elif file_name.ends_with(".txt"):
			# Extract archetype from folder structure
			var archetype = _extract_archetype_from_path(full_path, "res://Cards/Tokens")
			
			# Load token file
			var token_data = load_token_from_file(full_path, archetype)
			if token_data:
				tokensData.push_back(token_data)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _extract_archetype_from_path(file_path: String, root_path: String) -> Archetype:
	"""Extract archetype enum from file path based on subfolder name"""
	# Remove root path to get relative path
	var relative_path = file_path.replace(root_path + "/", "")
	
	# Strip leading slash if present (handles double slash issues)
	if relative_path.begins_with("/"):
		relative_path = relative_path.substr(1)
	
	# If there's no subfolder (file directly in root), return UNKNOWN
	if not "/" in relative_path:
		return Archetype.UNKNOWN
	
	# Get the first folder name
	var folder_name = relative_path.split("/")[0].to_upper()
	
	# Map folder name to archetype enum
	var result: Archetype
	match folder_name:
		"PUNGLYND":
			result = Archetype.PUNGLYND
		"NECROMANCER":
			result = Archetype.NECROMANCER
		_:
			result = Archetype.UNKNOWN
	return result

func get_archetype_pool(archetype: Archetype) -> Array[CardData]:
	"""Get all cards belonging to a specific archetype"""
	if archetype in archetype_pools:
		var pool = archetype_pools[archetype]
		if pool is Array:
			return pool
	var empty_pool: Array[CardData] = []
	return empty_pool

# Get a random opponent card
func getRandomOpponentCard() -> CardData:
	if opponentCards.size() > 0:
		return opponentCards[randi_range(0, opponentCards.size() - 1)]
	return null

func getRandomCard() -> CardData:
	return cardData[randi_range(0, cardData.size() - 1)]

# ─── Second-pass reference resolution ────────────────────────────────────────

func _resolve_pending_references():
	"""Second pass: resolve all queued cross-references between cards"""
	if pending_resolutions.is_empty():
		return
	print("[CARD LOAD] Resolving ", pending_resolutions.size(), " cross-reference(s)...")
	for entry in pending_resolutions:
		match entry["reason"]:
			ResolutionReason.PREPARED_SPELL:
				_resolve_prepared_spell(entry)
			_:
				push_warning("⚠️ [CARD LOAD] No resolver for reason: " + str(entry["reason"]))
	pending_resolutions.clear()

func _resolve_prepared_spell(entry: Dictionary):
	"""Resolve a PreparedSpell cross-reference.
	Calls prepare() on the holder with the found CardData, or removes the holder from all pools on failure."""
	var holder: CardData = entry["card"]
	var spell_name: String = entry["ref_name"]
	
	# Search all pools for the named spell
	var found: CardData = null
	for pool in [cardData, extraDeckCardData, tokensData, opponentCards]:
		for card in pool:
			if card.cardName.to_lower() == spell_name.to_lower():
				found = card
				break
		if found:
			break
	
	if found:
		holder.prepare(found)
		print("[CARD LOAD] ✅ '", holder.cardName, "' prepared with '", found.cardName, "'")
	else:
		push_error("❌ [CARD LOAD ERROR] PreparedSpell '" + spell_name + "' not found for card '" + holder.cardName + "' — removing card from all pools")
		_remove_card_from_all_pools(holder)

func _remove_card_from_all_pools(card: CardData):
	"""Remove a card from every pool it appears in"""
	cardData.erase(card)
	extraDeckCardData.erase(card)
	tokensData.erase(card)
	opponentCards.erase(card)
	for archetype in archetype_pools.keys():
		archetype_pools[archetype].erase(card)

# Helper functions to duplicate abilities with new owner reference
func _duplicate_triggered_ability(original: TriggeredAbility, new_owner: CardData) -> TriggeredAbility:
	# Debug logging for Grave Whisperer
	
	var copy = TriggeredAbility.new(new_owner, original.game_event_trigger, original.effect_type)
	copy.effect_parameters = original.effect_parameters.duplicate()
	copy.trigger_conditions = original.trigger_conditions.duplicate()
	copy.targeting_requirements = original.targeting_requirements.duplicate()
	return copy

func _duplicate_activated_ability(original: ActivatedAbility, new_owner: CardData) -> ActivatedAbility:
	var copy = ActivatedAbility.new(new_owner, original.effect_type)
	copy.effect_parameters = original.effect_parameters.duplicate()
	copy.targeting_requirements = original.targeting_requirements.duplicate()
	for cost in original.activation_costs:
		copy.activation_costs.append(cost.duplicate())
	return copy

func _duplicate_static_ability(original: StaticAbility, new_owner: CardData) -> StaticAbility:
	var copy = StaticAbility.new(new_owner, original.effect_type)
	copy.effect_parameters = original.effect_parameters.duplicate()
	copy.targeting_requirements = original.targeting_requirements.duplicate()
	return copy

func _duplicate_replacement_ability(original: ReplacementAbility, new_owner: CardData) -> ReplacementAbility:
	# Duplicate the replacement effect so it references the new owner
	var new_replacement_effect: ReplacementEffect = null
	if original.replacement_effect:
		# Create a new instance of the same type with updated owner
		var original_effect = original.replacement_effect
		new_replacement_effect = original_effect.get_script().new(
			new_owner,  # Use the new owner instead of the original
			original_effect.conditions.duplicate(),
			original_effect.modifications.duplicate()
		)
	
	var copy = ReplacementAbility.new(new_owner, original.effect_type, new_replacement_effect)
	copy.effect_parameters = original.effect_parameters.duplicate()
	copy.targeting_requirements = original.targeting_requirements.duplicate()
	return copy

# Custom deep copy method for CardData objects to replace broken duplicate() method
func duplicateCardScript(original: CardData) -> CardData:
	if not original:
		return null
	
	# Create a new CardData instance
	var copy = CardData.new()
	
	# Copy basic properties
	copy.cardName = original.cardName
	copy.goldCost = original.goldCost
	copy.power = original.power
	copy.text_box = original.text_box
	
	# Deep copy types array
	copy._types = original._types.duplicate()
	
	# Deep copy subtypes array
	copy._subtypes = original._subtypes.duplicate()
	
	# Deep copy keywords array
	copy._keywords = original._keywords.duplicate()
	
	# Deep copy additional costs
	var costs: Array[Dictionary] = []
	for cost in original.additionalCosts:
		costs.append(cost.duplicate())
	copy.additionalCosts = costs
	
	# Deep copy casting conditions
	copy.castingConditions = original.castingConditions.duplicate()
	
	# Deep copy abilities - each ability needs to reference the new card
	for ability in original.triggered_abilities:
		copy.triggered_abilities.append(_duplicate_triggered_ability(ability, copy))
	
	for ability in original.activated_abilities:
		copy.activated_abilities.append(_duplicate_activated_ability(ability, copy))
	
	for ability in original.static_abilities:
		copy.static_abilities.append(_duplicate_static_ability(ability, copy))
	
	for ability in original.replacement_abilities:
		copy.replacement_abilities.append(_duplicate_replacement_ability(ability, copy))
	
	# Deep copy spell_effects (simple dictionaries)
	for spell_effect in original.spell_effects:
		copy.spell_effects.append(spell_effect.duplicate(true))  # deep duplicate
	
	# Copy card art reference (texture resources are shared, not duplicated)
	copy.cardArt = original.cardArt
	
	# Copy controller/ownership properties
	copy.playerControlled = original.playerControlled
	copy.playerOwned = original.playerOwned
	
	# Preserve prepared-spell definition (set at load time via PreparedSpell:)
	copy.isPrepared = original.isPrepared
	copy.prepared_card = original.prepared_card  # shared reference to template
	
	# Don't copy runtime state (these should be fresh for new cards)
	copy.hasAttackedThisTurn = false
	copy.isTapped = false
	copy.card_object = null
	var temp_effects: Array[TemporaryEffect] = []
	copy.temporary_effects = temp_effects
	
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
