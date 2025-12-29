extends RefCounted
class_name ReplacementEffectManager

## Manages replacement effects that modify ability effects before execution
## Replacement effects are checked when abilities go on the trigger queue

static func apply_replacement_effects(effect_context: Dictionary, game_context: Game) -> Dictionary:
	"""
	Apply all applicable replacement effects to an effect context.
	This should be called before executing an effect.
	
	@param effect_context: Dictionary containing:
		- effect_type: String - Type of effect being modified
		- source_card_data: CardData - Card creating the effect
		- Any other effect-specific data
	@param game_context: Game - The game context
	@return: Modified effect_context with replacement effects applied
	"""
	var modified_context = effect_context.duplicate()
	
	# Get all cards that could have replacement effects
	var all_cards = game_context.getAllCardsInPlay()
	
	for card in all_cards:
		if not card.cardData or card.cardData.abilities.is_empty():
			continue
		
		for ability in card.cardData.abilities:
			if ability.get("type", "") != "ReplacementEffect":
				continue
			
			# Check if this replacement effect applies
			if _should_replacement_apply(ability, effect_context, card, game_context):
				# Apply the replacement effect
				modified_context = _apply_replacement(ability, modified_context, card)
	
	return modified_context

static func _should_replacement_apply(replacement_ability: Dictionary, effect_context: Dictionary, replacement_source: Card, game_context: Game) -> bool:
	"""Check if a replacement effect should apply to the given effect"""
	var effect_type = effect_context.get("effect_type", "")
	var ability_event_type = replacement_ability.get("event_type", "")
	
	# Standardize event type comparison
	var standardized_effect_type = _standardize_event_type(effect_type)
	var standardized_ability_type = _standardize_event_type(ability_event_type)
	
	if standardized_ability_type != standardized_effect_type:
		return false
	
	# Check ActiveZones condition
	var conditions = replacement_ability.get("replacement_conditions", {})
	var active_zones = conditions.get("ActiveZones", "Any")
	
	if active_zones != "Any":
		var replacement_source_zone = game_context.getCardZone(replacement_source)
		if not _is_zone_condition_met(active_zones, replacement_source_zone):
			return false
	
	# Check effect-specific conditions
	match standardized_effect_type:
		"CreateToken":
			return _check_token_creation_conditions(conditions, effect_context)
		_:
			# Add other effect-specific condition checks here
			return true

static func _check_token_creation_conditions(conditions: Dictionary, effect_context: Dictionary) -> bool:
	"""Check if token creation replacement effect applies"""
	var valid_token = conditions.get("ValidToken", "Any")
	if valid_token == "Any":
		return true
	
	# Parse condition like "Card.YouCtrl+Creature.Goblin"
	var condition_parts = valid_token.split("+")
	
	for single_condition in condition_parts:
		single_condition = single_condition.strip_edges()
		
		if single_condition == "Card.YouCtrl":
			# Token controller check would go here
			continue
		elif single_condition.begins_with("Creature."):
			var required_subtype = single_condition.substr(9)
			var token_data = effect_context.get("token_data") as CardData
			
			if not token_data:
				return false
			
			if not token_data.hasType(CardData.CardType.CREATURE):
				return false
			
			if not token_data.hasSubtype(required_subtype):
				return false
	
	return true

static func _is_zone_condition_met(zone_condition: String, actual_zone: GameZone.e) -> bool:
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

static func _apply_replacement(replacement_ability: Dictionary, effect_context: Dictionary, replacement_source: Card) -> Dictionary:
	"""Apply a replacement effect to modify the effect context"""
	var modified_context = effect_context.duplicate()
	var effect_parameters = replacement_ability.get("effect_parameters", {})
	var replacement_type = effect_parameters.get("Type", "")
	
	match replacement_type:
		"AddToken":
			# Modify token creation count
			var amount_to_add = int(effect_parameters.get("Amount", "0"))
			var current_amount = modified_context.get("tokens_to_create", 1)
			modified_context["tokens_to_create"] = current_amount + amount_to_add
			print("  📝 [REPLACEMENT] ", replacement_source.cardData.cardName, " adds ", amount_to_add, " token(s). Total: ", modified_context["tokens_to_create"])
		_:
			print("  ⚠️ Unknown replacement type: ", replacement_type)
	
	return modified_context

static func _standardize_event_type(event_type: String) -> String:
	"""Standardize event type strings for comparison"""
	match event_type:
		"CreateToken", "CREATE_TOKEN":
			return "CreateToken"
		_:
			return event_type
