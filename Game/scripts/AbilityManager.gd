extends RefCounted
class_name AbilityManager

# Manages triggered abilities and game events

static func trigger_zone_change_abilities(cards_with_abilities: Array, card: Card, additional_info: Array, game_context: Node = null):
	"""Trigger all abilities that respond to zone changes"""
	var relevant_abilities = get_abilities_by_trigger_type(cards_with_abilities, "CHANGES_ZONE")
	
	for ability_info in relevant_abilities:
		if should_trigger_ability(ability_info.ability_data, card, additional_info):
			execute_ability(ability_info.ability_data, ability_info.source_card, game_context)

static func trigger_card_played_abilities(cards_with_abilities: Array, played_card: Card, additional_info: Array, game_context: Node = null):
	"""Trigger all abilities that respond to cards being played"""
	var relevant_abilities = get_abilities_by_trigger_type(cards_with_abilities, "CARD_PLAYED")
	
	for ability_info in relevant_abilities:
		if should_trigger_ability(ability_info.ability_data, played_card, additional_info):
			execute_ability(ability_info.ability_data, ability_info.source_card, game_context)

static func get_abilities_by_trigger_type(cards_with_abilities: Array, trigger_type: String) -> Array:
	"""Filter and return all abilities of a specific trigger type with their source cards"""
	var filtered_abilities = []
	
	for ability_card in cards_with_abilities:
		if ability_card.cardData and ability_card.cardData.abilities:
			for ability_data in ability_card.cardData.abilities:
				if ability_data.trigger_type == trigger_type:
					filtered_abilities.append({
						"ability_data": ability_data,
						"source_card": ability_card
					})
	
	return filtered_abilities

static func should_trigger_ability(ability_data: Dictionary, triggering_card: Card, additional_info: Array) -> bool:
	"""Check if an ability should trigger based on event data"""
	var trigger_conditions = ability_data.get("trigger_conditions", {})
	
	match ability_data.trigger_type:
		"CHANGES_ZONE":
			return check_conditions_with_additional_info(trigger_conditions, triggering_card, additional_info)
		"CARD_PLAYED":
			return check_conditions_with_additional_info(trigger_conditions, triggering_card, additional_info)
	
	return false

static func check_conditions_with_additional_info(conditions: Dictionary, triggering_card: Card, additional_info: Array) -> bool:
	"""Generic condition checking that handles additional info parameters"""
	
	# Parse additional info into a dictionary for easier access
	var info_dict = parse_additional_info(additional_info)
	
	# Check each condition from the ability
	for condition_key in conditions.keys():
		var condition_value = conditions[condition_key]
		
		match condition_key:
			"Origin":
				if condition_value != "Any" and info_dict.get("origin", "") != condition_value:
					return false
			"Destination":
				if condition_value != "Any" and info_dict.get("destination", "") != condition_value:
					return false
			"ValidCard":
				if not check_valid_card_condition(condition_value, triggering_card):
					return false
			"ValidActivatingPlayer":
				if condition_value == "You" and not info_dict.get("is_owner_player", false):
					return false
			"TriggerZones":
				if condition_value != "Any" and condition_value != "Battlefield":
					# For now assume all triggers happen on battlefield
					return false
			_:
				# Unknown condition - log but don't fail
				print("Unknown trigger condition: ", condition_key, " = ", condition_value)
	
	return true

static func check_valid_card_condition(condition_value: String, triggering_card: Card) -> bool:
	"""Check ValidCard conditions"""
	match condition_value:
		"Any":
			return true
		"Card.Self":
			# This would require additional context to determine if the triggering card is the same as the ability source
			# For now, assume this check is handled elsewhere
			return true
		_:
			# Check if it's a subtype condition (like "Goblin")
			if triggering_card and triggering_card.cardData:
				return condition_value in triggering_card.cardData.subtypes
			return false

static func parse_additional_info(additional_info: Array) -> Dictionary:
	"""Parse additional info array into a dictionary"""
	var info_dict = {}
	
	for info in additional_info:
		if info is String and ":" in info:
			var parts = info.split(":", 1)
			if parts.size() == 2:
				info_dict[parts[0].strip_edges()] = parts[1].strip_edges()
		elif info is Dictionary:
			# If already a dictionary, merge it
			for key in info.keys():
				info_dict[key] = info[key]
	
	return info_dict

static func execute_ability(ability_data: Dictionary, source_card: Card, game_context: Node):
	"""Execute a triggered ability"""
	var effect_name = ability_data.get("effect_name", "")
	var effect_parameters = ability_data.get("effect_parameters", {})
	
	print("Executing ability: ", ability_data.get("description", "Unknown"))
	print("  Source card: ", source_card.cardData.cardName)
	print("  Effect: ", effect_name)
	
	match effect_name:
		"TrigToken", "TrigCreateGoblin":
			execute_token_creation(effect_parameters, source_card, game_context)
		_:
			push_error("Unknown effect: " + effect_name)

static func execute_token_creation(parameters: Dictionary, source_card: Card, game_context: Node):
	"""Execute token creation effect"""
	if "TokenScript" in parameters:
		var token_script = parameters["TokenScript"]
		print("Creating token: ", token_script, " for card: ", source_card.cardData.cardName)
		
		# Load the token data from the Cards/Tokens/ folder
		var token_path = "res://Cards/Tokens/" + token_script + ".txt"
		var token_card_data = CardLoader.load_card_from_file(token_path)
		
		if not token_card_data:
			push_error("Failed to load token: " + token_script)
			return
		
		# Create a new card instance
		var CARD = preload("res://Game/scenes/Card.tscn")
		var token_card = CARD.instantiate()
		game_context.add_child(token_card)
		token_card.setData(token_card_data)
		
		# Find the combat zone that contains the source card
		var source_combat_zone = find_combat_zone_for_card(source_card, game_context)
		if not source_combat_zone:
			push_error("Could not find combat zone for source card")
			token_card.queue_free()
			return
		
		# Find the first empty location for the player (true for player side)
		var empty_location = source_combat_zone.getFirstEmptyLocation(true)
		if empty_location:
			empty_location.setCard(token_card)
			token_card.animatePlayedTo(empty_location.global_position + Vector3(0, 0.1, 0))
			token_card.makeSmall()
			print("Token created successfully: ", token_card_data.cardName)
		else:
			print("No empty locations available for token")
			token_card.queue_free()

static func find_combat_zone_for_card(card: Card, game_context: Node):
	"""Find which combat zone contains the given card"""
	var combat_zones = game_context.combatZones
	
	for combat_zone in combat_zones:
		# Check ally spots (player side)
		for spot in combat_zone.allySpots:
			if spot.getCard() == card:
				return combat_zone
		
		# Check enemy spots
		for spot in combat_zone.enemySpots:
			if spot.getCard() == card:
				return combat_zone
	
	return null
