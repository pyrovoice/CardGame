extends RefCounted
class_name AbilityModifier

## Represents a static ability that modifies other abilities
## These are registered globally and checked when abilities enter the trigger queue

var source_card_data: CardData  ## The card that provides this modifier
var modifier_type: String  ## Type of modification ("AddToken", "IncreaseDamage", etc.)
var conditions: Dictionary  ## Conditions for when this modifier applies
var modifications: Dictionary  ## The modifications to apply
var replacement_effect: ReplacementEffect = null  ## The replacement effect implementation

func _init(source: CardData, type: String, cond: Dictionary, mods: Dictionary, effect: ReplacementEffect = null):
	source_card_data = source
	modifier_type = type
	conditions = cond
	modifications = mods
	replacement_effect = effect

func applies_to_ability(ability_effect_type: String, effect_parameters: Dictionary, game_context: Game) -> bool:
	"""
	Check if this modifier applies to the given ability.
	
	@param ability_effect_type: String - The type of effect being modified
	@param effect_parameters: Dictionary - The effect parameters
	@param game_context: Game - The game context
	@return: bool - True if this modifier should be applied
	"""
	
	# Check if the source card is still valid
	var source_card = source_card_data.get_card_object()
	if not source_card or not is_instance_valid(source_card):
		return false
	
	# Check ActiveZones condition
	var active_zones = conditions.get("ActiveZones", "Any")
	if active_zones != "Any":
		var source_zone = game_context.getCardZone(source_card)
		if not _is_zone_valid(active_zones, source_zone):
			return false
	
	# Check event type match
	var event_type = conditions.get("EventType", "")
	if event_type.is_empty():
		return false
	
	var standardized_event = _standardize_event_type(event_type)
	var standardized_ability = _standardize_event_type(ability_effect_type)
	
	if standardized_event != standardized_ability:
		return false
	
	# Check effect-specific conditions
	match standardized_event:
		"CreateToken":
			return _check_token_conditions(effect_parameters)
		"DealDamage":
			return _check_damage_conditions(effect_parameters)
		_:
			return true

func apply_modifications(effect_parameters: Dictionary) -> Dictionary:
	"""
	Apply this modifier's changes to the effect parameters.
	
	@param effect_parameters: Dictionary - Original effect parameters
	@return: Dictionary - Modified effect parameters
	"""
	# If we have a ReplacementEffect instance, use it
	if replacement_effect:
		# Create context with parameters and static ability info
		var effect_context = effect_parameters.duplicate()
		effect_context["static_ability_parameters"] = modifications
		
		# Apply the replacement effect
		return replacement_effect.apply_modification(effect_context, source_card_data, null)
	
	# Fallback to old dictionary-based system for backward compatibility
	var modified_params = effect_parameters.duplicate()
	
	match modifier_type:
		"AddToken":
			# Add additional tokens to creation
			var amount_to_add = int(modifications.get("Amount", "0"))
			var current_amount = modified_params.get("tokens_to_create", 1)
			modified_params["tokens_to_create"] = current_amount + amount_to_add
			print("  📝 [MODIFIER] ", source_card_data.cardName, " adds ", amount_to_add, " token(s). Total: ", modified_params["tokens_to_create"])
		
		"IncreaseDamage":
			# Increase damage dealt
			var amount_to_add = int(modifications.get("Amount", "0"))
			var current_damage = modified_params.get("NumDamage", 0)
			modified_params["NumDamage"] = current_damage + amount_to_add
			print("  📝 [MODIFIER] ", source_card_data.cardName, " adds ", amount_to_add, " damage. Total: ", modified_params["NumDamage"])
		
		"MultiplyTokens":
			# Multiply token creation
			var multiplier = int(modifications.get("Multiplier", "1"))
			var current_amount = modified_params.get("tokens_to_create", 1)
			modified_params["tokens_to_create"] = current_amount * multiplier
			print("  📝 [MODIFIER] ", source_card_data.cardName, " multiplies tokens by ", multiplier, ". Total: ", modified_params["tokens_to_create"])
		
		_:
			print("  ⚠️ Unknown modifier type: ", modifier_type)
	
	return modified_params

func _check_token_conditions(effect_parameters: Dictionary) -> bool:
	"""Check if token creation conditions are met"""
	var valid_token = conditions.get("ValidToken", "Any")
	if valid_token == "Any":
		return true
	
	# Need token data to check conditions
	# This will be loaded by the ability system before checking
	var token_script = effect_parameters.get("TokenScript", "")
	if token_script.is_empty():
		return false
	
	var token_data = CardLoaderAL.load_token_by_name(token_script)
	if not token_data:
		return false
	
	# Parse condition like "Card.YouCtrl+Creature.Goblin"
	var condition_parts = valid_token.split("+")
	
	for single_condition in condition_parts:
		single_condition = single_condition.strip_edges()
		
		if single_condition == "Card.YouCtrl":
			# Token controller check
			continue
		elif single_condition.begins_with("Creature."):
			var required_subtype = single_condition.substr(9)
			
			if not token_data.hasType(CardData.CardType.CREATURE):
				return false
			
			if not token_data.hasSubtype(required_subtype):
				return false
	
	return true

func _check_damage_conditions(effect_parameters: Dictionary) -> bool:
	"""Check if damage conditions are met"""
	# Add damage-specific condition checking here
	return true

func _is_zone_valid(zone_condition: String, actual_zone: GameZone.e) -> bool:
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

func _standardize_event_type(event_type: String) -> String:
	"""Standardize event type strings for comparison"""
	match event_type:
		"CreateToken", "CREATE_TOKEN":
			return "CreateToken"
		"DealDamage", "DEAL_DAMAGE":
			return "DealDamage"
		_:
			return event_type
