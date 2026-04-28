extends Node
class_name AbilityManager

# Manages triggered abilities and game events
# Singleton
# NEW SYSTEM: Abilities self-register when created and enabled
# AbilityManager only handles execution, not registration

## Ability execution methods

func activateAbility(source_card_data: CardData, activated_ability: ActivatedAbility, game_context: Game, pre_selections: SelectionManager.CardPlaySelections = null):
	print("🔥 [ACTIVATED] Activating ability on ", source_card_data.cardName)
	
	# First, check if costs can be paid
	if not CardPaymentManagerAL.canPayCosts(activated_ability.activation_costs, source_card_data):
		print("⚠️ Cannot pay activation costs for ", source_card_data.cardName)
		return false
	
	var card_name_for_debug = source_card_data.cardName  # Store card name before potential destruction

	
	# Pay costs - payCosts returns info for game_context to execute
	var payment_info = CardPaymentManagerAL.payCosts(activated_ability.activation_costs, source_card_data, pre_selections)
	if not payment_info.success:
		print("❌ Failed to pay activation costs for ", card_name_for_debug)
		return false
	
	# Execute payment: spend gold
	if payment_info.gold_to_pay > 0:
		if not game_context.game_data.spend_gold(payment_info.gold_to_pay, source_card_data.playerControlled):
			print("❌ Failed to spend gold for activation")
			return false
	
	# Execute payment: sacrifice cards
	for sacrifice_card_data in payment_info.cards_to_sacrifice:
		var dest_zone = GameZone.e.GRAVEYARD_PLAYER if sacrifice_card_data.playerOwned else GameZone.e.GRAVEYARD_OPPONENT
		await game_context.execute_move_card(sacrifice_card_data, dest_zone)
	
	# Execute payment: tap card if needed
	if payment_info.card_to_tap:
		payment_info.card_to_tap.tap()
	
	# Execute the ability effect using CardData (which persists even if Card is freed)
	await executeAbilityEffect(source_card_data, activated_ability, game_context)
	
	# Resolve state-based actions after ability execution
	game_context.resolveStateBasedAction()
	
	print("✅ [ACTIVATED] Completed ability activation")
	return true

func executeAbilityEffect(source_card_data: CardData, ability, game_context: Game):
	"""
	Unified method to execute ability effects - used for triggered and activated abilities.
	After an ability is triggered or activated, this handles the actual effect execution.
	Uses enum-based effect types for type safety and consistency.
	Uses CardData instead of Card object, so effects work even if the Card has been destroyed.
	
	Accepts TriggeredAbility, ActivatedAbility, StaticAbility, ReplacementAbility, or Dictionary (legacy)
	"""
	var effect_type_str: String
	var effect_parameters: Dictionary
	var target_conditions: Dictionary
	
	# Check ability type and extract data
	if ability is TriggeredAbility or ability is ActivatedAbility or ability is StaticAbility or ability is ReplacementAbility:
		effect_type_str = EffectType.type_to_string(ability.effect_type)
		effect_parameters = ability.effect_parameters
		# TriggeredAbility uses trigger_conditions, ActivatedAbility uses targeting_requirements
		if ability is TriggeredAbility:
			target_conditions = ability.trigger_conditions
		elif ability is ActivatedAbility:
			target_conditions = ability.targeting_requirements
		else:
			target_conditions = {}
	elif ability is Dictionary:
		effect_type_str = ability.get("effect_type", "")
		effect_parameters = ability.get("effect_parameters", {})
		target_conditions = ability.get("target_conditions", {})
	else:
		print("❌ Invalid ability type: ", typeof(ability))
		return
	
	if effect_type_str.is_empty():
		print("❌ No effect_type specified for ability on card: ", source_card_data.cardName)
	
	if effect_type_str.is_empty():
		print("❌ No effect_type specified for ability on card: ", source_card_data.cardName)
		print("   Ability data: ", ability)
		return
	
	# Convert string to enum
	var effect_type_enum: EffectType.Type = EffectType.string_to_type(effect_type_str)
	
	print("🔥 [ABILITY] Executing effect: ", EffectType.type_to_string(effect_type_enum), " with parameters: ", effect_parameters)
	
	# Resolve targets at the ability level (before effect execution)
	var resolved_parameters = effect_parameters.duplicate()

	# Merge target conditions generically; effect classes decide how to resolve targets.
	for condition_key in target_conditions.keys():
		if not resolved_parameters.has(condition_key):
			resolved_parameters[condition_key] = target_conditions[condition_key]

	# Resolve targets at orchestration level (not inside effects).
	# If required targeting cannot be satisfied, cancel effect execution.
	var has_preselected_targets = resolved_parameters.has("Targets") and not resolved_parameters.get("Targets", []).is_empty()
	var has_targeting_spec = resolved_parameters.has("Target") or resolved_parameters.has("ValidCards") or resolved_parameters.has("ValidTargets")
	var requires_targets = bool(target_conditions.get("required", false)) or EffectType.requires_targeting(effect_type_enum)

	if not has_preselected_targets and has_targeting_spec:
		var resolved_targets = TargetResolver.resolve_targets(resolved_parameters, source_card_data, game_context)
		if not resolved_targets.is_empty():
			resolved_parameters["Targets"] = resolved_targets

	if requires_targets and (not resolved_parameters.has("Targets") or resolved_parameters.get("Targets", []).is_empty()):
		print("⚠️ No valid targets resolved for required effect ", EffectType.type_to_string(effect_type_enum), " on ", source_card_data.cardName, " - cancelling effect")
		return
	
	# Apply replacement effects from the registry
	# This happens before the effect executes
	resolved_parameters = ReplacementEffectRegistry.apply_replacement_effects(
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
	
	# Query GameData for cards in play
	var cards_data = game_context.game_data.get_cards_in_play()
	
	for card_data in cards_data:
		if card_data.replacement_abilities.is_empty():
			continue
		
		for ability in card_data.replacement_abilities:
			# Check if this replacement effect applies to the current effect
			if shouldReplacementEffectApply(ability, effect_context, card_data, game_context):
				# Apply the replacement effect
				modified_context = applyReplacementEffect(ability, modified_context, card_data)
	
	return modified_context

func shouldReplacementEffectApply(replacement_ability: ReplacementAbility, effect_context: Dictionary, replacement_source_data: CardData, game_context: Game) -> bool:
	"""Check if a replacement effect should apply to the current effect"""
	var effect_type = effect_context.get("effect_type", "")
	var ability_event_type = replacement_ability.effect_parameters.get("event_type", "")
	
	# Check if the event type matches using ReplacementType for consistency
	# Convert both to standardized format for comparison
	var standardized_effect_type = _standardize_replacement_event_type(effect_type)
	var standardized_ability_type = _standardize_replacement_event_type(ability_event_type)
	
	if standardized_ability_type != standardized_effect_type:
		return false
	
	# Check ActiveZones condition
	var conditions = replacement_ability.effect_parameters.get("replacement_conditions", {})
	var active_zones = conditions.get("ActiveZones", "Any")
	
	if active_zones != "Any":
		var replacement_source_zone = game_context.game_data.get_card_zone(replacement_source_data)
		if active_zones == "Battlefield":
			if not GameZone.is_in_play(replacement_source_zone):
				return false
		elif active_zones == "Hand":
			if replacement_source_zone not in [GameZone.e.HAND_PLAYER, GameZone.e.HAND_OPPONENT]:
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
			return GameZone.is_in_play(actual_zone)
		"Hand":
			return actual_zone in [GameZone.e.HAND_PLAYER, GameZone.e.HAND_OPPONENT]
		"Graveyard":
			return actual_zone in [GameZone.e.GRAVEYARD_PLAYER, GameZone.e.GRAVEYARD_OPPONENT]
		"Deck":
			return actual_zone in [GameZone.e.DECK_PLAYER, GameZone.e.DECK_OPPONENT]
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

func applyReplacementEffect(replacement_ability: ReplacementAbility, effect_context: Dictionary, _replacement_source_data: CardData) -> Dictionary:
	"""Apply a replacement effect to modify the effect context"""
	var modified_context = effect_context.duplicate()
	var effect_params = replacement_ability.effect_parameters
	var replacement_type = effect_params.get("Type", "")
	
	match replacement_type:
		"AddToken":
			# Add additional tokens to be created
			var amount_to_add = int(effect_params.get("Amount", "0"))
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

func executeSpellEffects(card_data: CardData, game_context: Game):
	"""Execute spell effects - handle targeting and effect resolution"""
	if not card_data.hasType(CardData.CardType.SPELL):
		print("❌ Tried to execute spell effects on non-spell card: ", card_data.cardName)
		return
	
	print("✨ Casting spell: ", card_data.cardName)
	
	# Get spell effects from the card
	var spell_effects = card_data.spell_effects
	
	if spell_effects.is_empty():
		print("⚠️ Spell has no effects to execute: ", card_data.cardName)
		return
	
	# Execute each spell effect
	for effect in spell_effects:
		await executeSpellEffect(card_data, effect, game_context)
	
	print("✨ Finished casting spell: ", card_data.cardName)

func executeSpellEffect(card_data: CardData, effect: Dictionary, game_context: Game):
	"""Execute a single spell effect - converts to enum and calls executeAbilityEffect"""
	var effect_type_str = effect.get("effect_type", "")
	
	if effect_type_str.is_empty():
		print("❌ No effect_type specified for spell effect")
		return
	
	# Convert to unified ability format and execute through executeAbilityEffect
	var ability = {
		"type": "SpellEffect",
		"effect_type": effect_type_str,
			"effect_parameters": effect.get("effect_parameters", {}),
		"target_conditions": {}
	}
	
	await executeAbilityEffect(card_data, ability, game_context)

## Validation and Condition Checking
## Used by the deprecated trigger system and for card condition validation

func isValidCardCondition(condition: String, triggerSource_data: CardData, abilityOwner_data: CardData) -> bool:
	"""Check if the trigger source meets the ValidCard condition"""
	if condition == "Any":
		return true
	elif condition == "Card.Self":
		return triggerSource_data == abilityOwner_data
	elif condition == "Card.Other":
		return triggerSource_data != abilityOwner_data
	else:
		# Check if it's a subtype condition (e.g., "Goblin")
		if triggerSource_data and triggerSource_data.subtypes:
			return condition in triggerSource_data.subtypes
	
	return false

func evaluateCondition(condition: String, triggeringCard_data: CardData) -> bool:
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
	var target_card_data: CardData = null
	match target:
		"Self":
			target_card_data = triggeringCard_data
		_:
			push_warning("Unsupported condition target: " + target)
			return false
	
	# Check the property with timing
	match property:
		"Attacked":
			if timing == "ThisTurn":
				return target_card_data.hasAttackedThisTurn
			else:
				push_warning("Unsupported timing for Attacked: " + timing)
				return false
		_:
			push_warning("Unsupported condition property: " + property)
			return false
