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
	
	# Resolve state-based actions after all triggered abilities have executed
	if triggeredAbilities.size() > 0:
		game.resolveStateBasedAction()

func execute_token_creation(parameters: Dictionary, source_card: Card, game_context: Game):
	"""Execute token creation effect"""
	var token_script = parameters.get("TokenScript", "")
	if token_script.is_empty():
		print("❌ No TokenScript specified for token creation")
		return
	
	# Load the token data from the tokensData array
	var token_data = CardLoaderAL.load_token_by_name(token_script)
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
		var card = game_context.createToken(token_data, source_card.cardData.playerControlled)
		game_context.executeCardEnters(card, GameZone.e.UNKNOWN, GameZone.e.UNKNOWN)

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

func execute_add_type(parameters: Dictionary, source_card: Card, game_context: Game):
	"""Execute AddType effect - add types/subtypes to target cards"""
	
	# Parse target - defaults to Self
	var target_param = parameters.get("Target", "Self")
	var target_cards: Array[Card] = []
	
	match target_param:
		"Self":
			target_cards = [source_card]
		_:
			print("❌ Unsupported AddType target: ", target_param)
			return
	
	# Parse types to add
	var types_to_add = parameters.get("Types", "")
	if types_to_add.is_empty():
		print("❌ No types specified for AddType effect")
		return
	
	# Parse duration
	var duration = parameters.get("Duration", "Permanent")
	
	# Add the types to each target card
	for target_card in target_cards:
		add_type_to_card(target_card, types_to_add, duration, game_context)

func add_type_to_card(target_card: Card, types_string: String, duration: String, game_context: Game):
	"""Add types/subtypes to a card with specified duration"""
	
	# Split types by space if multiple types specified
	var type_parts = types_string.split(" ")
	
	for type_part in type_parts:
		type_part = type_part.strip_edges()
		if type_part.is_empty():
			continue
		
		# Check if it's a main card type or subtype
		if CardData.isValidCardTypeString(type_part):
			# It's a main card type - use CardData's addType method
			var card_type = CardData.stringToCardType(type_part)
			target_card.cardData.addType(card_type)
			print("✨ Added type ", type_part, " to ", target_card.cardData.cardName)
		else:
			# It's a subtype - use CardData's addSubtype method
			target_card.cardData.addSubtype(type_part)
			print("✨ Added subtype ", type_part, " to ", target_card.cardData.cardName)
		
		# Handle duration-based removal
		match duration:
			"Permanent":
				# Nothing to do - changes are permanent
				pass
			"EndOfTurn":
				# Schedule removal at end of turn
				schedule_type_removal(target_card, type_part, "EndOfTurn", game_context)
			"WhileInPlay":
				# Schedule removal when card leaves play
				schedule_type_removal(target_card, type_part, "WhileInPlay", game_context)
			_:
				print("❌ Unsupported AddType duration: ", duration)

func schedule_type_removal(target_card: Card, type_to_remove: String, duration: String, game_context: Game):
	"""Schedule type removal based on duration"""
	# TODO: Implement duration-based type removal system
	# This would require a more sophisticated effect tracking system
	print("⏰ Scheduled removal of ", type_to_remove, " from ", target_card.cardData.cardName, " at ", duration)
	print("  (Duration-based removal not yet implemented)")

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
			if not token_data.hasType(CardData.CardType.CREATURE):
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
	var actionTriggerType = action.trigger_type  # Use enum value directly
	
	for triggeringObject in cards:
		# Check if the card has any triggered abilities
		if not triggeringObject.cardData or triggeringObject.cardData.abilities.is_empty():
			continue
		
		for ability: Dictionary in triggeringObject.cardData.abilities:
			if ability.get("type", "") != "TriggeredAbility":
				continue
			
			# Check if this ability's trigger type matches the current trigger
			var ability_trigger_type = ability.get("trigger_type", TriggerType.Type.CARD_ENTERS)
			
			if ability_trigger_type == actionTriggerType:
				# Additional validation for specific trigger types
				if actionTriggerType == TriggerType.Type.CARD_ENTERS:
					# Check Origin and Destination conditions for card enters
					var origin_condition = ability.get("trigger_conditions", {}).get("Origin", "Any")
					var destination_condition = ability.get("trigger_conditions", {}).get("Destination", "Any")
					
					# Validate origin condition
					if not _isZoneConditionMet(origin_condition, action.from_zone):
						continue
					
					# Validate destination condition  
					if not _isZoneConditionMet(destination_condition, action.to_zone):
						continue
				
				elif actionTriggerType == TriggerType.Type.CARD_PLAYED:
					# Check if there's a specific Origin condition
					var origin_condition = ability.get("trigger_conditions", {}).get("Origin", "Any")
					if not _isZoneConditionMet(origin_condition, action.from_zone):
						continue
					
					# Validate destination is battlefield (where cards are "played" to)
					if not action.is_battlefield_entry():
						continue
				
				elif actionTriggerType == TriggerType.Type.PHASE:
					# Check if the phase matches the specified phase condition
					var phase_condition = ability.get("trigger_conditions", {}).get("Phase", "")
					var action_phase = action.additional_data.get("phase", "")
					
					# Normalize phase names for comparison
					var normalized_condition = phase_condition.replace(" ", "").replace("of", "").replace("Of", "")
					var normalized_action = action_phase.replace(" ", "").replace("of", "").replace("Of", "")
					
					if phase_condition.is_empty() or normalized_condition != normalized_action:
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
				
				# Check additional trigger condition
				var trigger_condition = ability.get("trigger_conditions", {}).get("Condition", "")
				if not trigger_condition.is_empty():
					if not evaluateCondition(trigger_condition, triggeringObject, action):
						continue
				
				# If we get here, the ability should trigger
				triggeredAbilities.append({"card": triggeringObject, "ability": ability})
	
	return triggeredAbilities

func executeAbility(triggeringCard: Card, ability: Dictionary, game_context: Game):
	"""Execute a specific triggered ability"""
	var effect_name = ability.get("effect_name", "")
	var effect_parameters = ability.get("effect_parameters", {})
	
	print("🔥 [TRIGGER DEBUG] Executing ability for ", triggeringCard.cardData.cardName, " - Effect: ", effect_name)
	
	match effect_name:
		"TrigToken":
			# Call the existing token creation logic
			print("🔥 [TRIGGER DEBUG] Creating token with parameters: ", effect_parameters)
			execute_token_creation(effect_parameters, triggeringCard, game_context)
		"TrigDraw", "Draw":
			# Call the existing draw card logic
			execute_draw_card(effect_parameters, triggeringCard, game_context)
		"TrigGrowup":
			# Call the add type logic
			execute_add_type(effect_parameters, triggeringCard, game_context)
		_:
			print("❌ Unknown effect: ", effect_name)

func executeSpellEffects(card: Card, game_context: Game):
	"""Execute spell effects - handle targeting and effect resolution"""
	if not card.cardData.hasType(CardData.CardType.SPELL):
		print("❌ Tried to execute spell effects on non-spell card: ", card.cardData.cardName)
		return
	
	print("✨ Casting spell: ", card.cardData.cardName)
	
	# Get spell effects from the card's abilities
	var spell_effects = []
	for ability in card.cardData.abilities:
		if ability.get("type") == "SpellEffect":
			spell_effects.append(ability)
	
	if spell_effects.is_empty():
		print("⚠️ Spell has no effects to execute: ", card.cardData.cardName)
		return
	
	# Execute each spell effect
	for effect in spell_effects:
		await executeSpellEffect(card, effect, game_context)
	
	print("✨ Finished casting spell: ", card.cardData.cardName)

func executeSpellEffect(card: Card, effect: Dictionary, game_context: Game):
	"""Execute a single spell effect"""
	var effect_type = effect.get("effect_type", "")
	var parameters = effect.get("parameters", {})
	
	match effect_type:
		"DealDamage":
			await executeSpellDamage(card, parameters, game_context)
		_:
			print("❌ Unknown spell effect type: ", effect_type)

func executeSpellDamage(card: Card, parameters: Dictionary, game_context: Game):
	"""Execute spell damage effect with targeting"""
	var damage_amount = parameters.get("NumDamage", 1)
	var valid_targets = parameters.get("ValidTargets", "Any")
	
	print("⚡ ", card.cardData.cardName, " needs to deal ", damage_amount, " damage to target (", valid_targets, ")")
	
	# Get all possible targets based on ValidTargets
	var possible_targets: Array[Card] = []
	
	match valid_targets:
		"Any":
			# Can target any card in play or the player
			possible_targets = game_context.getAllCardsInPlay()
			# Note: We'll need to handle player targeting separately
		"Creature":
			# Can only target creatures
			for target_card in game_context.getAllCardsInPlay():
				if target_card.cardData.hasType(CardData.CardType.CREATURE):
					possible_targets.append(target_card)
		_:
			print("❌ Unknown target type: ", valid_targets)
			return
	
	if possible_targets.is_empty():
		print("⚠️ No valid targets for ", card.cardData.cardName)
		return
	
	# Start target selection
	var requirement = {
		"valid_card": "Any",  # We've already filtered the possible_targets
		"count": 1
	}
	
	print("🎯 Starting target selection for ", card.cardData.cardName)
	var selected_targets = await game_context.start_selection_with_casting_card(requirement, possible_targets, "spell_target_" + card.cardData.cardName, card)
	
	if selected_targets.is_empty():
		print("❌ No target selected for ", card.cardData.cardName)
		return
	
	var target = selected_targets[0]
	print("⚡ ", card.cardData.cardName, " deals ", damage_amount, " damage to ", target.cardData.cardName)
	
	# Apply damage
	target.receiveDamage(damage_amount)
	
	# Show damage animation
	AnimationsManagerAL.show_floating_text(game_context, target.global_position, "-" + str(damage_amount), Color.RED)
	
	# Resolve state-based actions after damage
	game_context.resolveStateBasedAction()

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

func evaluateCondition(condition: String, triggeringCard: Card, action: GameAction) -> bool:
	"""Evaluate trigger conditions like Self.Attacked+ThisTurn"""
	# Parse condition format: Target.Property+Timing
	# Example: Self.Attacked+ThisTurn
	
	var condition_parts = condition.split(".")
	if condition_parts.size() != 2:
		push_warning("Invalid condition format: " + condition)
		return false
	
	var target = condition_parts[0]
	var property_and_timing = condition_parts[1]
	
	# Split property and timing by +
	var property_parts = property_and_timing.split("+")
	if property_parts.size() != 2:
		push_warning("Invalid condition property format: " + property_and_timing)
		return false
	
	var property = property_parts[0]
	var timing = property_parts[1]
	
	# Resolve the target card
	var target_card: Card = null
	match target:
		"Self":
			target_card = triggeringCard
		_:
			push_warning("Unsupported condition target: " + target)
			return false
	
	# Check the property with timing
	match property:
		"Attacked":
			if timing == "ThisTurn":
				return target_card.cardData.hasAttackedThisTurn
			else:
				push_warning("Unsupported timing for Attacked: " + timing)
				return false
		_:
			push_warning("Unsupported condition property: " + property)
			return false
	
	return false
