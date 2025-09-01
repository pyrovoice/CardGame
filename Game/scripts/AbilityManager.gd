extends RefCounted
class_name AbilityManager

# Manages triggered abilities and game events
# Main entry point for trigger detection when cards enter battlefield

static func detect_and_trigger_abilities(game_context: Node, triggering_event: String, triggering_card: Card, additional_info: Dictionary = {}):
	"""Main function to detect and trigger all relevant abilities when an event occurs"""
	print("=== Ability Trigger Detection ===")
	print("Event: ", triggering_event)
	print("Triggering card: ", triggering_card.cardData.cardName if triggering_card else "None")
	
	# Get all cards that could have triggers
	var cards_to_check = get_all_cards_in_trigger_zones(game_context, triggering_event)
	print("Cards to check for triggers: ", cards_to_check.size())
	
	# Check each card for matching triggers
	for card in cards_to_check:
		if not card.cardData or card.cardData.abilities.is_empty():
			continue
		
		check_and_execute_card_abilities(card, triggering_event, triggering_card, game_context, additional_info)

static func get_all_cards_in_trigger_zones(game_context: Node, event: String) -> Array[Card]:
	"""Get all cards that should be checked for triggers based on event type"""
	var cards: Array[Card] = []
	
	# Always check battlefield cards (combat zones + player base)
	cards.append_array(get_battlefield_cards(game_context))
	
	# For certain events, also check other zones
	match event:
		"CARD_ENTERS_BATTLEFIELD":
			# Most enter battlefield triggers are on battlefield cards
			pass
		"TURN_START", "TURN_END":
			# These might also trigger from hand
			cards.append_array(get_hand_cards(game_context))
	
	return cards

static func get_battlefield_cards(game_context: Node) -> Array[Card]:
	"""Get all cards currently on the battlefield"""
	var cards: Array[Card] = []
	
	# Check combat zones
	if game_context.has_method("get") and game_context.combatZones:
		for combat_zone in game_context.combatZones:
			# Get cards from ally spots
			for spot in combat_zone.allySpots:
				var card = spot.getCard()
				if card:
					cards.append(card)
			
			# Get cards from enemy spots (note: it's "ennemySpots" with double 'n')
			for spot in combat_zone.ennemySpots:
				var card = spot.getCard()
				if card:
					cards.append(card)
	
	# Check player base
	var player_base = game_context.find_child("playerBase")
	if player_base:
		for child in player_base.get_children():
			if child is Card:
				cards.append(child)
	
	return cards

static func get_hand_cards(game_context: Node) -> Array[Card]:
	"""Get all cards in player's hand"""
	var cards: Array[Card] = []
	
	var player_hand = game_context.find_child("PlayerHand")
	if player_hand:
		for child in player_hand.get_children():
			if child is Card:
				cards.append(child)
	
	return cards

static func check_and_execute_card_abilities(card: Card, event: String, triggering_card: Card, game_context: Node, additional_info: Dictionary):
	"""Check all abilities on a card and execute matching ones"""
	for ability in card.cardData.abilities:
		if should_ability_trigger(ability, event, triggering_card, card, additional_info):
			print("🔥 TRIGGER: ", card.cardData.cardName, " - ", ability.get("description", "Unknown effect"))
			execute_ability(ability, card, game_context, triggering_card)

static func should_ability_trigger(ability: Dictionary, event: String, triggering_card: Card, ability_owner: Card, _additional_info: Dictionary) -> bool:
	"""Check if this specific ability should trigger for this event"""
	
	# Only check triggered abilities
	if ability.get("type", "") != "TriggeredAbility":
		return false
	
	# Check if the trigger type matches the event
	if not does_trigger_match_event(ability.get("trigger_type", ""), event):
		return false
	
	# Check all trigger conditions
	var conditions = ability.get("trigger_conditions", {})
	
	# ValidCard condition (what cards can trigger this ability)
	if "ValidCard" in conditions:
		if not check_valid_card_condition(conditions["ValidCard"], triggering_card, ability_owner):
			return false
	
	# TriggerZones condition (where the ability owner must be)
	if "TriggerZones" in conditions:
		if not check_trigger_zones_condition(conditions["TriggerZones"], ability_owner):
			return false
	
	# Origin/Destination conditions for zone changes
	if event == "CARD_ENTERS_BATTLEFIELD":
		if "Destination" in conditions and conditions["Destination"] != "Battlefield":
			return false
		if "Origin" in conditions and conditions["Origin"] != "Any":
			# Could add more specific origin checking if needed
			pass
	
	return true

static func does_trigger_match_event(trigger_type: String, event: String) -> bool:
	"""Check if a trigger type matches an event"""
	match trigger_type:
		"CHANGES_ZONE":
			return event in ["CARD_ENTERS_BATTLEFIELD", "CARD_LEAVES_BATTLEFIELD"]
		"CARD_PLAYED":
			return event == "CARD_PLAYED"
		"TURN_START":
			return event == "TURN_START"
		"TURN_END":
			return event == "TURN_END"
		_:
			return false

static func check_valid_card_condition(condition: String, triggering_card: Card, ability_owner: Card) -> bool:
	"""Check ValidCard condition"""
	match condition:
		"Any":
			return true
		"Card.Self":
			return triggering_card == ability_owner
		_:
			# Check for subtype conditions (like "Creature.Goblin")
			if "." in condition:
				var parts = condition.split(".")
				if parts.size() >= 2:
					var card_type = parts[0]  # e.g., "Creature"
					var subtype = parts[1]    # e.g., "Goblin"
					
					if triggering_card and triggering_card.cardData:
						# Check type matches
						if card_type == "Creature" and triggering_card.cardData.type != CardData.CardType.CREATURE:
							return false
						# Check subtype matches
						if not subtype in triggering_card.cardData.subtypes:
							return false
						return true
			
			# Simple subtype check
			if triggering_card and triggering_card.cardData:
				return condition in triggering_card.cardData.subtypes
			
			return false

static func check_trigger_zones_condition(condition: String, ability_owner: Card) -> bool:
	"""Check TriggerZones condition - where the ability owner must be located"""
	match condition:
		"Any":
			return true
		"Battlefield":
			# Check if ability owner is on battlefield (in combat zone or player base)
			var parent = ability_owner.get_parent()
			return parent is CombatantFightingSpot or parent is PlayerBase
		"Hand":
			# Check if in hand
			var parent = ability_owner.get_parent()
			return parent and parent.name == "PlayerHand"
		_:
			# Unknown zone, assume false
			return false

static func execute_ability(ability: Dictionary, source_card: Card, game_context: Node, _triggering_card: Card = null):
	"""Execute a triggered ability"""
	var effect_name = ability.get("effect_name", "")
	var effect_parameters = ability.get("effect_parameters", {})
	
	print("⚡ Executing ability: ", ability.get("description", "Unknown"))
	print("  Source: ", source_card.cardData.cardName)
	print("  Effect: ", effect_name)
	
	match effect_name:
		"TrigToken":
			execute_token_creation(effect_parameters, source_card, game_context)
		_:
			print("❌ Unknown effect: ", effect_name)

static func execute_token_creation(parameters: Dictionary, source_card: Card, game_context: Node):
	"""Execute token creation effect"""
	var token_script = parameters.get("TokenScript", "")
	if token_script.is_empty():
		print("❌ No TokenScript specified for token creation")
		return
	
	print("🎭 Creating token: ", token_script, " for: ", source_card.cardData.cardName)
	
	# Load the token data from the Cards/Tokens/ folder
	var token_path = "res://Cards/Tokens/" + token_script + ".txt"
	var token_data = CardLoader.load_card_from_file(token_path)
	
	if not token_data:
		print("❌ Failed to load token from: ", token_path)
		return
	
	# Create the token card
	var token_card = create_token_card(token_data, game_context)
	if not token_card:
		print("❌ Failed to create token card instance")
		return
	
	# Determine placement location
	var placement_location = determine_token_placement(source_card, game_context)
	if placement_location:
		place_token_at_location(token_card, placement_location)
		print("✅ Token created successfully: ", token_data.cardName)
	else:
		print("❌ No valid placement location found for token")
		token_card.queue_free()

static func create_token_card(token_data: CardData, game_context: Node) -> Card:
	"""Create a new Card instance from token data"""
	# Create a copy of the token data and modify it to be a proper token
	var modified_token_data = CardData.new(
		token_data.cardName,
		0,  # Tokens typically cost 0
		token_data.type,
		token_data.power,
		token_data.text_box,
		token_data.subtypes.duplicate()
	)
	
	var CARD = preload("res://Game/scenes/Card.tscn")
	var token_card = CARD.instantiate()
	game_context.add_child(token_card)
	token_card.setData(modified_token_data)
	
	# Set up token like a played card
	token_card.makeSmall()  # Tokens start small
	# Apply the same rotation that played cards have
	token_card.rotation_degrees.x = -90  # Card object rotation
	token_card.card_representation.rotation_degrees = Vector3(90, 90, 90)  # CardRepresentation rotation
	token_card.angleInHand = Vector3(90, 90, 90)  # Store the rotation state
	token_card.cardControlState = Card.CardControlState.FREE  # Set to free state
	
	return token_card

static func determine_token_placement(source_card: Card, game_context: Node) -> Node3D:
	"""Determine where to place the created token (same location as source)"""
	var parent = source_card.get_parent()
	
	if parent is CombatantFightingSpot:
		# Find the combat zone containing this spot
		var combat_zone = parent.get_parent()
		if combat_zone and combat_zone.has_method("getFirstEmptyLocation"):
			# Place on the same side (ally side) as the source
			return combat_zone.getFirstEmptyLocation(true)  # true = ally side
	
	# Fallback: place at player base
	return game_context.find_child("playerBase")

static func place_token_at_location(token_card: Card, location: Node3D):
	"""Place token card at the specified location"""
	if location is CombatantFightingSpot:
		location.setCard(token_card, false)
	elif location is PlayerBase:
		# Simple placement at player base
		var position = location.getNextEmptyLocation()
		token_card.reparent(location, false)
		token_card.position = position
	else:
		print("❌ Unknown location type for token placement: ", location.get_class())
