class_name CardAbility extends RefCounted

var owner_card_data: WeakRef  # Reference to the CardData that owns this ability
var effect_type: EffectType.Type  # What effect does this ability have
var effect_parameters: Dictionary  # Parameters for the effect (token name, damage amount, etc.)
var targeting_requirements: Dictionary  # For abilities that need targets
var description = ""

func _init(p_owner: CardData):
	owner_card_data = weakref(p_owner)
	effect_parameters = {}
	targeting_requirements = {}

## Builder methods for configuring abilities

func with_effect_parameters(params: Dictionary) -> CardAbility:
	"""Set effect parameters (token name, damage amount, etc.)"""
	effect_parameters = params
	return self



func with_targeting(target_params: Dictionary) -> CardAbility:
	"""Set targeting requirements"""
	targeting_requirements = target_params
	return self

## Query methods

func has_targeting() -> bool:
	return not targeting_requirements.is_empty()

func get_owner() -> CardData:
	"""Get the CardData that owns this ability"""
	if owner_card_data:
		return owner_card_data.get_ref()
	return null

func requires_target() -> bool:
	"""Check if this ability requires selecting a target"""
	return has_targeting() and targeting_requirements.get("required", false)

func get_description() -> String:
	"""Get a human-readable description of this ability"""
	var desc = EffectType.type_to_string(effect_type)
	
	# Add key parameters to description
	if effect_parameters.has("token_name"):
		desc += " (Token: " + str(effect_parameters["token_name"]) + ")"
	elif effect_parameters.has("NumDamage"):
		desc += " (" + str(effect_parameters["NumDamage"]) + " damage)"
	elif effect_parameters.has("NumDraw"):
		desc += " (Draw " + str(effect_parameters["NumDraw"]) + ")"
	
	return desc

## Example usage documentation:
## 
## # Create a "When this enters play, create a Goblin token" ability
## var ability = TriggeredAbility.new(
##     card_data,
##     TriggeredAbility.GameEvent.CARD_ENTERED_PLAY,
##     EffectType.Type.CREATE_TOKEN
## ).with_effect_parameters({
##     "token_name": "Goblin",
##     "count": 1
## }).with_trigger_condition("ValidCards", "Card.Self")
##
## # Create an activated ability "Pay 1, Sacrifice Self: Grant all creatures Spellshield"
## var ability = ActivatedAbility.new(
##     card_data,
##     EffectType.Type.ADD_KEYWORD
## ).with_activation_cost({
##     "type": "PayMana",
##     "amount": 1
## }).with_activation_cost({
##     "type": "Sacrifice",
##     "target": "Self"
## }).with_effect_parameters({
##     "KW": "Spellshield",
##     "ValidCards": "Creature.YouCtrl",
##     "Duration": "EndOfTurn"
## })
##
## # Create a static ability "Other Goblins you control get +1/+1"
## var ability = StaticAbility.new(
##     card_data,
##     EffectType.Type.PUMP
## ).with_effect_parameters({
##     "PowerBonus": 1,
##     "ValidCards": "Creature.YouCtrl+Goblin"
## })
