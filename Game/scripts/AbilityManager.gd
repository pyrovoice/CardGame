extends Node
class_name AbilityManager

# Manages triggered abilities and game events
# Singleton
# NEW SYSTEM: Abilities self-register when created and enabled
# AbilityManager only handles execution, not registration

## Ability execution methods

func activateAbility(source_card: Card, activated_ability: Dictionary, game_context: Game):
	"""Execute an activated ability - entry point for player-activated abilities"""
	print("🔥 [ACTIVATED] Activating ability on ", source_card.cardData.cardName)
	
	# First, check if costs can be paid
	if not canPayActivationCosts(source_card, activated_ability, game_context):
		print("⚠️ Cannot pay activation costs for ", source_card.cardData.cardName)
		return false
	
	# Check if any cost would destroy the source card (like Sacrifice Self)
	var has_sacrifice_self_cost = false
	var card_name_for_debug = source_card.cardData.cardName  # Store card name before potential destruction
	var source_card_data = source_card.cardData  # Store CardData reference before card might be freed
	var activation_costs = activated_ability.get("activation_costs", [])
	for cost in activation_costs:
		if cost.get("type", "") == "Sacrifice" and cost.get("target", "") == "Self":
			has_sacrifice_self_cost = true
			break
	
	# Always pay costs first (proper order for sacrificing)
	if not await payActivationCosts(source_card, activated_ability, game_context):
		print("❌ Failed to pay activation costs for ", card_name_for_debug)
		return false
	
	# Execute the ability effect using CardData (which persists even if Card is freed)
	await executeAbilityEffect(source_card_data, activated_ability, game_context)
	
	# Resolve state-based actions after ability execution
	game_context.resolveStateBasedAction()
	
	print("✅ [ACTIVATED] Completed ability activation")
	return true

func canPayActivationCosts(source_card: Card, activated_ability: Dictionary, game_context: Game) -> bool:
	"""Check if the activation costs can be paid"""
	var activation_costs = activated_ability.get("activation_costs", [])
	
	for cost in activation_costs:
		var cost_type = cost.get("type", "")
		match cost_type:
			"Sacrifice":
				var target = cost.get("target", "")
				if target == "Self":
					# Can always sacrifice self if the card is in play
					var source_zone = game_context.getCardZone(source_card)
					if source_zone != GameZone.e.PLAYER_BASE and source_zone != GameZone.e.COMBAT_ZONE:
						return false
				else:
					print("❌ Unsupported sacrifice target: ", target)
					return false
			
			"PayMana":
				var amount = cost.get("amount", 0)
				if game_context.game_data.player_gold.getValue() < amount:
					return false
			
			"Tap":
				var target = cost.get("target", "")
				if target == "Self":
					# Check if the card can be tapped
					if not source_card.cardData.can_tap():
						return false
				else:
					print("❌ Unsupported tap target: ", target)
					return false
			
			_:
				print("❌ Unknown activation cost type: ", cost_type)
				return false
	
	return true

func payActivationCosts(source_card: Card, activated_ability: Dictionary, game_context: Game) -> bool:
	"""Pay the activation costs for the ability"""
	var activation_costs = activated_ability.get("activation_costs", [])
	
	for cost in activation_costs:
		var cost_type = cost.get("type", "")
		match cost_type:
			"Sacrifice":
				var target = cost.get("target", "")
				if target == "Self":
					print("🔥 Sacrificing ", source_card.cardData.cardName, " for activated ability")
					# Move the card to graveyard
					game_context.putInOwnerGraveyard(source_card)
				else:
					print("❌ Unsupported sacrifice target: ", target)
					return false
			
			"PayMana":
				var amount = cost.get("amount", 0)
				print("💰 Paying ", amount, " mana for activated ability")
				var current_gold = game_context.game_data.player_gold.getValue()
				game_context.game_data.player_gold.setValue(current_gold - amount)
			
			"Tap":
				var target = cost.get("target", "")
				if target == "Self":
					print("🔄 Tapping ", source_card.cardData.cardName, " for activated ability")
					source_card.cardData.tap()
				else:
					print("❌ Unsupported tap target: ", target)
					return false
			
			_:
				print("❌ Unknown activation cost type: ", cost_type)
				return false
	
	# Small delay to show the cost payment
	await game_context.get_tree().process_frame
	return true

func executeAbilityEffect(source_card_data: CardData, ability, game_context: Game):
	"""
	Unified method to execute ability effects - used for both triggered and activated abilities.
	After an ability is triggered or activated, this handles the actual effect execution.
	Uses enum-based effect types for type safety and consistency.
	Uses CardData instead of Card object, so effects work even if the Card has been destroyed.
	
	Accepts TriggeredAbility, ActivatedAbility, StaticAbility, or Dictionary (legacy)
	"""
	var effect_type_str: String
	var effect_parameters: Dictionary
	var target_conditions: Dictionary
	
	# Check ability type and extract data
	if ability is TriggeredAbility or ability is ActivatedAbility or ability is StaticAbility:
		effect_type_str = EffectType.type_to_string(ability.effect_type)
		effect_parameters = ability.effect_parameters
		target_conditions = ability.trigger_conditions if "trigger_conditions" in ability else {}
	elif ability is Dictionary:
		effect_type_str = ability.get("effect_type", "")
		effect_parameters = ability.get("effect_parameters", {})
		target_conditions = ability.get("target_conditions", {})
	else:
		print("❌ Invalid ability type: ", typeof(ability))
		return
	
	if effect_type_str.is_empty():
		print("❌ No effect_type specified for ability on card: ", source_card_data.cardName)
		print("   Ability data: ", ability)
		return
	
	# Convert string to enum
	var effect_type_enum: EffectType.Type = EffectType.string_to_type(effect_type_str)
	
	print("🔥 [ABILITY] Executing effect: ", EffectType.type_to_string(effect_type_enum), " with parameters: ", effect_parameters)
	
	# Resolve targets at the ability level (before effect execution)
	var resolved_parameters = effect_parameters.duplicate()
	
	# For effects that need target resolution
	match effect_type_enum:
		EffectType.Type.ADD_KEYWORD:
			# Merge ValidCards from target_conditions
			if target_conditions.has("ValidCards"):
				resolved_parameters["ValidCards"] = target_conditions.get("ValidCards")
			# Resolve targets
			var targets = TargetResolver.resolve_targets(resolved_parameters, source_card_data, game_context)
			resolved_parameters["Targets"] = targets
		
		EffectType.Type.ADD_TYPE:
			# Resolve Self or other targets
			var targets = TargetResolver.resolve_targets(resolved_parameters, source_card_data, game_context)
			resolved_parameters["Targets"] = targets
	
	# Apply ability modifiers from the registry (replacement effects, static modifiers, etc.)
	# This happens when the ability "enters the trigger queue"
	resolved_parameters = AbilityModifierRegistry.apply_modifiers_to_effect(
		effect_type_str, 
		resolved_parameters, 
		game_context
	)
	
	# Execute the effect with resolved and modified parameters
	await EffectFactory.execute_effect(effect_type_enum, resolved_parameters, source_card_data, game_context)

## Replacement Effect System (Legacy - kept for compatibility)
## New code should use ReplacementEffectManager instead

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

## Spell Effect Execution
## Handles spell casting and effect resolution

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
	"""Execute a single spell effect - converts to enum and calls executeAbilityEffect"""
	var effect_type_str = effect.get("effect_type", "")
	
	if effect_type_str.is_empty():
		print("❌ No effect_type specified for spell effect")
		return
	
	# Convert to unified ability format and execute through executeAbilityEffect
	var ability = {
		"type": "SpellEffect",
		"effect_type": effect_type_str,
		"effect_parameters": effect.get("parameters", {}),
		"target_conditions": {}
	}
	
	await executeAbilityEffect(card.cardData, ability, game_context)

## Validation and Condition Checking
## Used by the deprecated trigger system and for card condition validation

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
