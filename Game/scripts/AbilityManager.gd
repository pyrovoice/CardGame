extends Node
class_name AbilityManager

# Manages triggered abilities and game events
# Singleton
# Main entry point for trigger detection when game action happens


func triggerGameAction(game:Game, triggerSource: Card, from: GameZone.e, to: GameZone.e, isPlayed = false):
	var objectsInCorrectLocationToTrigger = game.getAllCardsInPlay().filter(func(c: Card): return isCorrectTriggerLocation(c, game.getCardZone(c)))
	var triggeredAbilities = getTriggeredAbilities(objectsInCorrectLocationToTrigger, triggerSource, from, to, isPlayed)
	
	for abilityPair in triggeredAbilities:
		var triggeringCard = abilityPair.card
		var ability = abilityPair.ability
		# Execute the specific ability
		executeAbility(triggeringCard, ability)

func execute_token_creation(parameters: Dictionary, source_card: Card, game_context: Game):
	"""Execute token creation effect"""
	var token_script = parameters.get("TokenScript", "")
	if token_script.is_empty():
		print("❌ No TokenScript specified for token creation")
		return
	
	# Load the token data from the Cards/Tokens/ folder
	var token_path = "res://Cards/Tokens/" + token_script + ".txt"
	var token_data = CardLoader.load_card_from_file(token_path)
	var card = game_context.createCardFromData(token_data)
	game_context.playCardToPlayerBase(card)

static func create_token_card(token_data: CardData, _game_context: Node) -> Card:
	"""Create a new Card instance for the token"""
	var card_scene = preload("res://Game/scenes/Card.tscn")
	var token_card = card_scene.instantiate()
	
	# Set the card data BEFORE adding to scene tree
	token_card.cardData = token_data
	
	# Don't set rotation here - wait until after _ready() is called
	return token_card

static func place_token_at_location(token_card: Card, location: Node3D):
	"""Place the token card at the specified location"""
	
	# Add to scene tree first so _ready() gets called
	location.add_child(token_card)
	
	# Use call_deferred to set rotation after _ready() completes
	token_card.call_deferred("_set_token_rotation")
	
	if location.has_method("getNextEmptyLocation"):
		# This is a PlayerBase
		var target_pos = location.getNextEmptyLocation()
		if target_pos != Vector3.INF:
			# Use position relative to parent
			token_card.position = target_pos + Vector3(0, 0.1, 0)
		else:
			print("❌ No empty location available for token")
	else:
		# Generic placement
		token_card.position = Vector3.ZERO
	
	# Call updateDisplay after the card is in the scene tree and positioned
	if token_card.has_method("updateDisplay"):
		token_card.updateDisplay()
	
	# Set objectID if not set
	if not token_card.objectID:
		token_card.objectID = token_card.cardData.cardName + "_token_" + str(Time.get_unix_time_from_system())

func isCorrectTriggerLocation(triggeringObject: Card, current_zone: GameZone.e):
	# Check each ability on the card to see if any have trigger zone restrictions
	if not triggeringObject.cardData or triggeringObject.cardData.abilities.is_empty():
		return false
	
	for ability in triggeringObject.cardData.abilities:
		if ability.get("type", "") != "TriggeredAbility":
			continue
			
		var trigger_zones = ability.get("trigger_conditions", {}).get("TriggerZones", "Any")
		
		# If no trigger zone specified or "Any", the ability can trigger from anywhere
		if trigger_zones == "Any":
			return true
		
		# Check if current zone matches the required trigger zone
		if trigger_zones == "Battlefield":
			# Battlefield includes both PLAYER_BASE and COMBAT_ZONE
			if current_zone == GameZone.e.PLAYER_BASE or current_zone == GameZone.e.COMBAT_ZONE:
				return true
		elif trigger_zones == "Hand":
			if current_zone == GameZone.e.HAND:
				return true
		elif trigger_zones == "Graveyard":
			if current_zone == GameZone.e.GRAVEYARD:
				return true
		elif trigger_zones == "Deck":
			if current_zone == GameZone.e.DECK:
				return true
	
	return false
	
func getTriggeredAbilities(cards: Array[Card], triggerSource: Card, from: GameZone.e, to: GameZone.e, isPlayed = false) -> Array:
	"""Return an array of {card: Card, ability: Dictionary} pairs for abilities that should trigger"""
	var triggeredAbilities = []
	var triggerType = getTriggerType(triggerSource, from, to, isPlayed)
	
	for triggeringObject in cards:
		# Check if the card has any triggered abilities
		if not triggeringObject.cardData or triggeringObject.cardData.abilities.is_empty():
			continue
		
		for ability in triggeringObject.cardData.abilities:
			if ability.get("type", "") != "TriggeredAbility":
				continue
			
			# Check if this ability's trigger type matches the current trigger
			var ability_trigger_type = ability.get("trigger_type", "")
			
			if ability_trigger_type == triggerType:
				# Additional validation for specific trigger types
				if triggerType == "CHANGES_ZONE":
					# Check Origin and Destination conditions
					var origin_condition = ability.get("trigger_conditions", {}).get("Origin", "Any")
					var destination_condition = ability.get("trigger_conditions", {}).get("Destination", "Any")
					
					# Validate origin condition
					if origin_condition != "Any":
						if origin_condition == "Battlefield" and from != GameZone.e.PLAYER_BASE and from != GameZone.e.COMBAT_ZONE:
							continue
						elif origin_condition == "Hand" and from != GameZone.e.HAND:
							continue
						elif origin_condition == "Graveyard" and from != GameZone.e.GRAVEYARD:
							continue
						elif origin_condition == "Deck" and from != GameZone.e.DECK:
							continue
					
					# Validate destination condition  
					if destination_condition != "Any":
						if destination_condition == "Battlefield" and to != GameZone.e.PLAYER_BASE and to != GameZone.e.COMBAT_ZONE:
							continue
						elif destination_condition == "Hand" and to != GameZone.e.HAND:
							continue
						elif destination_condition == "Graveyard" and to != GameZone.e.GRAVEYARD:
							continue
						elif destination_condition == "Deck" and to != GameZone.e.DECK:
							continue
				
				elif triggerType == "CARD_PLAYED":
					# Add validation for card played triggers if needed
					pass
				
				# Check ValidCard condition
				var valid_card_condition = ability.get("trigger_conditions", {}).get("ValidCard", "Any")
				if not isValidCardCondition(valid_card_condition, triggerSource, triggeringObject):
					continue
				
				# Check ValidActivatingPlayer condition
				var valid_player_condition = ability.get("trigger_conditions", {}).get("ValidActivatingPlayer", "Any")
				if valid_player_condition == "You":
					# For now, assume all actions are from "You" (the player)
					# This could be expanded to support multiplayer
					pass
				elif valid_player_condition == "Opponent":
					# Skip for now since we don't have opponent actions
					continue
				
				# If we get here, the ability should trigger
				triggeredAbilities.append({"card": triggeringObject, "ability": ability})
	
	return triggeredAbilities

func executeAbility(triggeringCard: Card, ability: Dictionary):
	"""Execute a specific triggered ability"""
	var effect_name = ability.get("effect_name", "")
	var effect_parameters = ability.get("effect_parameters", {})
	
	match effect_name:
		"TrigToken":
			# For now, we'll need to pass the game context from the caller
			# This is a temporary solution until we can access it properly
			print("⚡ Token creation triggered by: ", triggeringCard.cardData.cardName)
			print("  Effect parameters: ", effect_parameters)
		_:
			print("❌ Unknown effect: ", effect_name)

func isValidCardCondition(condition: String, triggerSource: Card, abilityOwner: Card) -> bool:
	"""Check if the trigger source meets the ValidCard condition"""
	if condition == "Any":
		return true
	elif condition == "Card.Self":
		return triggerSource == abilityOwner
	elif condition == "Card.Other":
		return triggerSource != abilityOwner
	else:
		# Check if it's a subtype condition (e.g., "Goblin")
		if triggerSource.cardData and triggerSource.cardData.subtypes:
			return condition in triggerSource.cardData.subtypes
	
	return false
	
func getTriggerType(_triggerSource: Card, from: GameZone.e, to: GameZone.e, isPlayed = false):
	# getTriggerType depending on parameters. For example, from hand to Player_Base would return ChangesZone
	
	# If isPlayed is true, this is explicitly a card being played
	if isPlayed:
		return "CARD_PLAYED"
	
	# If zones are different, this is a zone change
	if from != to:
		return "CHANGES_ZONE"
	
	# Add more trigger types as needed:
	# - Attacks
	# - Dies  
	# - Deals damage
	# - etc.
	
	# Default fallback
	return "CHANGES_ZONE"
