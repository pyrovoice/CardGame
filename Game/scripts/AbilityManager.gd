extends Node
class_name AbilityManager

# Manages triggered abilities and game events
# Singleton
# Main entry point for trigger detection when game action happens


func triggerGameAction(game: Game, action: GameAction):
	var objectsInCorrectLocationToTrigger = game.getAllCardsInPlay().filter(func(c: Card): return isCorrectTriggerLocation(c, game.getCardZone(c)))
	var triggeredAbilities = getTriggeredAbilities(objectsInCorrectLocationToTrigger, action)
	
	for abilityPair in triggeredAbilities:
		var triggeringCard = abilityPair.card
		var ability = abilityPair.ability
		# Execute the specific ability
		executeAbility(triggeringCard, ability, game)

func execute_token_creation(parameters: Dictionary, source_card: Card, game_context: Game):
	"""Execute token creation effect"""
	var token_script = parameters.get("TokenScript", "")
	if token_script.is_empty():
		print("❌ No TokenScript specified for token creation")
		return
	
	# Load the token data from the tokensData array
	var token_data = CardLoader.load_token_by_name(token_script)
	if not token_data:
		print("❌ Failed to load token: " + token_script)
		return
	
	# Check for replacement effects before creating tokens
	var effect_context = {
		"effect_type": "CreateToken",
		"source_card": source_card,
		"token_data": token_data,
		"tokens_to_create": 1,  # Default amount
		"game_context": game_context
	}
	
	# Apply replacement effects
	effect_context = onEffectTrigger(effect_context, game_context)
	
	# Create the modified number of tokens
	var tokens_to_create = effect_context.get("tokens_to_create", 1)
	for i in range(tokens_to_create):
		var card = game_context.createCardFromData(token_data)
		card.global_position = effect_context.get("source_card", source_card).global_position
		game_context.moveCardToPlayerBase(card)

func execute_draw_card(parameters: Dictionary, source_card: Card, game_context: Game):
	"""Execute draw card effect"""
	# Check who should draw the card (default to "You" if not specified)
	var defined_player = parameters.get("Defined", "You")
	if defined_player != "You":
		print("⚡ Draw card triggered by: ", source_card.cardData.cardName)
		print("  But effect is for: ", defined_player, " (not implemented for non-player)")
		return
	
	# Get the number of cards to draw
	var cards_to_draw = 1  # Default to 1
	if parameters.has("NumCards"):
		cards_to_draw = int(parameters.get("NumCards", "1"))
	elif parameters.has("Amount"):
		cards_to_draw = int(parameters.get("Amount", "1"))
	elif parameters.has("CardsDrawn"):
		cards_to_draw = int(parameters.get("CardsDrawn", "1"))
	
	print("⚡ Draw card triggered by: ", source_card.cardData.cardName)
	print("  Drawing ", cards_to_draw, " card(s) for: ", defined_player)
	
	# Draw the specified number of cards
	for i in range(cards_to_draw):
		game_context.drawCard()

func onEffectTrigger(effect_context: Dictionary, game_context: Game) -> Dictionary:
	"""Check for replacement effects that modify the given effect"""
	var modified_context = effect_context.duplicate()
	
	# Get all cards that could have replacement effects
	var all_cards = game_context.getAllCardsInPlay()
	
	for card in all_cards:
		if not card.cardData or card.cardData.abilities.is_empty():
			continue
		
		for ability in card.cardData.abilities:
			if ability.get("type", "") != "ReplacementEffect":
				continue
			
			# Check if this replacement effect applies to the current effect
			if shouldReplacementEffectApply(ability, effect_context, card, game_context):
				# Apply the replacement effect
				modified_context = applyReplacementEffect(ability, modified_context, card)
	
	return modified_context

func shouldReplacementEffectApply(replacement_ability: Dictionary, effect_context: Dictionary, replacement_source: Card, game_context: Game) -> bool:
	"""Check if a replacement effect should apply to the current effect"""
	var effect_type = effect_context.get("effect_type", "")
	var ability_event_type = replacement_ability.get("event_type", "")
	
	# Check if the event type matches using ReplacementType for consistency
	# Convert both to standardized format for comparison
	var standardized_effect_type = _standardize_replacement_event_type(effect_type)
	var standardized_ability_type = _standardize_replacement_event_type(ability_event_type)
	
	if standardized_ability_type != standardized_effect_type:
		return false
	
	# Check ActiveZones condition
	var conditions = replacement_ability.get("replacement_conditions", {})
	var active_zones = conditions.get("ActiveZones", "Any")
	
	if active_zones != "Any":
		var replacement_source_zone = game_context.getCardZone(replacement_source)
		if active_zones == "Battlefield":
			if replacement_source_zone != GameZone.e.PLAYER_BASE and replacement_source_zone != GameZone.e.COMBAT_ZONE:
				return false
		elif active_zones == "Hand":
			if replacement_source_zone != GameZone.e.HAND:
				return false
		# Add other zones as needed
	
	# Check ValidToken condition for token creation
	if standardized_effect_type == "CreateToken":
		var valid_token = conditions.get("ValidToken", "Any")
		if valid_token != "Any":
			if not isValidTokenCondition(valid_token, effect_context):
				return false
	
	return true

# Helper method to standardize replacement event types
func _standardize_replacement_event_type(event_type: String) -> String:
	match event_type:
		"CreateToken", "CREATE_TOKEN":
			return "CreateToken"
		_:
			return event_type

# Helper method to check if a zone condition is met
func _isZoneConditionMet(zone_condition: String, actual_zone: GameZone.e) -> bool:
	"""Check if the actual zone meets the specified zone condition"""
	if zone_condition == "Any":
		return true
	
	match zone_condition:
		"Battlefield":
			return actual_zone == GameZone.e.PLAYER_BASE or actual_zone == GameZone.e.COMBAT_ZONE
		"Hand":
			return actual_zone == GameZone.e.HAND
		"Graveyard":
			return actual_zone == GameZone.e.GRAVEYARD
		"Deck":
			return actual_zone == GameZone.e.DECK
		_:
			return false

func isValidTokenCondition(condition: String, effect_context: Dictionary) -> bool:
	"""Check if the token being created matches the ValidToken condition"""
	if condition == "Any":
		return true
	
	# Parse condition like "Card.YouCtrl+Creature.Goblin"
	var conditions = condition.split("+")
	
	for single_condition in conditions:
		single_condition = single_condition.strip_edges()
		
		if single_condition == "Card.YouCtrl":
			# For now, assume all tokens are created under player control
			continue
		elif single_condition.begins_with("Creature."):
			# Check if token is a creature with specific subtype
			var required_subtype = single_condition.substr(9)  # Remove "Creature."
			var token_data = effect_context.get("token_data") as CardData
			
			if not token_data:
				return false
			
			# Check if it's a creature
			if token_data.type != CardData.CardType.CREATURE:
				return false
			
			# Check if it has the required subtype
			if not token_data.subtypes or not (required_subtype in token_data.subtypes):
				return false
	
	return true

func applyReplacementEffect(replacement_ability: Dictionary, effect_context: Dictionary, _replacement_source: Card) -> Dictionary:
	"""Apply a replacement effect to modify the effect context"""
	var modified_context = effect_context.duplicate()
	var effect_parameters = replacement_ability.get("effect_parameters", {})
	var replacement_type = effect_parameters.get("Type", "")
	
	match replacement_type:
		"AddToken":
			# Add additional tokens to be created
			var amount_to_add = int(effect_parameters.get("Amount", "0"))
			var current_amount = modified_context.get("tokens_to_create", 1)
			modified_context["tokens_to_create"] = current_amount + amount_to_add
			print("  Adding ", amount_to_add, " additional token(s). Total: ", modified_context["tokens_to_create"])
		_:
			print("  Unknown replacement type: ", replacement_type)
	
	return modified_context

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
	
func getTriggeredAbilities(cards: Array[Card], action: GameAction) -> Array:
	"""Return an array of {card: Card, ability: Dictionary} pairs for abilities that should trigger"""
	var triggeredAbilities = []
	var triggerType = action.get_trigger_type_string()  # Use GameAction's trigger type
	
	for triggeringObject in cards:
		# Check if the card has any triggered abilities
		if not triggeringObject.cardData or triggeringObject.cardData.abilities.is_empty():
			continue
		
		for ability: Dictionary in triggeringObject.cardData.abilities:
			if ability.get("type", "") != "TriggeredAbility":
				continue
			
			# Check if this ability's trigger type matches the current trigger
			var ability_trigger_type = ability.get("trigger_type", "")
			
			if ability_trigger_type == triggerType:
				# Additional validation for specific trigger types
				if triggerType == "CardEnters":
					# Check Origin and Destination conditions for card enters
					var origin_condition = ability.get("trigger_conditions", {}).get("Origin", "Any")
					var destination_condition = ability.get("trigger_conditions", {}).get("Destination", "Any")
					
					# Validate origin condition
					if not _isZoneConditionMet(origin_condition, action.from_zone):
						continue
					
					# Validate destination condition  
					if not _isZoneConditionMet(destination_condition, action.to_zone):
						continue
				
				elif triggerType == "CardPlayed":
					# Check if there's a specific Origin condition
					var origin_condition = ability.get("trigger_conditions", {}).get("Origin", "Any")
					if not _isZoneConditionMet(origin_condition, action.from_zone):
						continue
					
					# Validate destination is battlefield (where cards are "played" to)
					if not action.is_battlefield_entry():
						continue
				
				# Check ValidCard condition
				var valid_card_condition = ability.get("trigger_conditions", {}).get("ValidCard", "Any")
				if not isValidCardCondition(valid_card_condition, action.trigger_source, triggeringObject):
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

func executeAbility(triggeringCard: Card, ability: Dictionary, game_context: Game):
	"""Execute a specific triggered ability"""
	var effect_name = ability.get("effect_name", "")
	var effect_parameters = ability.get("effect_parameters", {})
	
	match effect_name:
		"TrigToken":
			# Call the existing token creation logic
			execute_token_creation(effect_parameters, triggeringCard, game_context)
		"TrigDraw", "Draw":
			# Call the existing draw card logic
			execute_draw_card(effect_parameters, triggeringCard, game_context)
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
