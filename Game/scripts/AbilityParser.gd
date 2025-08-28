extends RefCounted
class_name AbilityParser

# Parses abilities from card text and creates appropriate Ability objects

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

static func parse_triggered_ability(trigger_text: String, svar_effects: Dictionary) -> TriggeredAbility:
	var trigger_parts = trigger_text.split(" | ")
	var trigger_conditions: Dictionary = {}
	var effect_name: String = ""
	var description: String = ""
	
	# Parse trigger conditions and parameters
	for part in trigger_parts:
		part = part.strip_edges()
		if part.begins_with("Mode$"):
			var mode = part.substr(6)  # Remove "Mode$ "
			# Map mode to trigger type
			match mode:
				"ChangesZone":
					# Will create CHANGES_ZONE trigger
					pass
		elif part.begins_with("Origin$"):
			trigger_conditions["Origin"] = part.substr(8)
		elif part.begins_with("Destination$"):
			trigger_conditions["Destination"] = part.substr(13)
		elif part.begins_with("ValidCard$"):
			trigger_conditions["ValidCard"] = part.substr(11)
		elif part.begins_with("Execute$"):
			effect_name = part.substr(9)
		elif part.begins_with("TriggerDescription$"):
			description = part.substr(20)
	
	# Get effect parameters from SVar
	var effect_parameters: Dictionary = {}
	if effect_name in svar_effects:
		effect_parameters = parse_effect_parameters(svar_effects[effect_name])
	
	# Create triggered ability
	var triggered_ability = TriggeredAbility.new(
		TriggeredAbility.TriggerType.CHANGES_ZONE,
		trigger_conditions,
		effect_name,
		effect_parameters,
		description
	)
	
	return triggered_ability

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
