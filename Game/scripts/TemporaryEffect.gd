class_name TemporaryEffect extends RefCounted

## Represents a temporary effect applied to a card
## Used for tracking effects that expire (EndOfTurn, EndOfCombat, etc.)

enum Duration {
	END_OF_TURN,
	END_OF_COMBAT,
	PERMANENT,    # Doesn't expire (until explicitly removed)
	CUSTOM        # Custom duration logic
}

enum ModificationType {
	ADDITIVE,      # Add to existing value (+2 power, add keyword)
	REPLACEMENT    # Replace entire value (becomes 0, gain control)
}

var effect_type: EffectType.Type
var duration: Duration
var modification_type: ModificationType = ModificationType.ADDITIVE
var property_name: String = ""     # Name of the property this effect modifies
var source_card_data: WeakRef  # Weak reference to the CardData that granted this effect

# Type-specific data
var keyword: String = ""           # For ADD_KEYWORD type
var type_to_add: String = ""       # For ADD_TYPE type
var subtype_to_add: String = ""    # For ADD_TYPE type (subtype)
var power_bonus: int = 0           # For PUMP type
var replacement_value = null       # For REPLACEMENT modifications
var granted_ability: Dictionary = {}  # For ABILITY type (if we add it later)

func _init(p_effect_type: EffectType.Type, p_duration: Duration, p_source_data: CardData = null):
	effect_type = p_effect_type
	duration = p_duration
	set_source_card_data(p_source_data)

## Factory methods for creating specific effect types

static func create_keyword_effect(keyword_name: String, effect_duration: Duration, source_data: CardData = null) -> TemporaryEffect:
	"""Create a temporary keyword effect (e.g., Spellshield, Flying)"""
	var effect = TemporaryEffect.new(EffectType.Type.ADD_KEYWORD, effect_duration, source_data)
	effect.property_name = "keywords"
	effect.modification_type = ModificationType.ADDITIVE
	effect.keyword = keyword_name
	return effect

static func create_type_effect(type_name: String, is_subtype: bool, effect_duration: Duration, source_data: CardData = null) -> TemporaryEffect:
	"""Create a temporary type/subtype effect"""
	var effect = TemporaryEffect.new(EffectType.Type.ADD_TYPE, effect_duration, source_data)
	effect.modification_type = ModificationType.ADDITIVE
	if is_subtype:
		effect.property_name = "subtypes"
		effect.subtype_to_add = type_name
	else:
		effect.property_name = "types"
		effect.type_to_add = type_name
	return effect

static func create_power_boost_effect(power_change: int, effect_duration: Duration, source_data: CardData = null, is_replacement: bool = false) -> TemporaryEffect:
	"""Create a temporary power boost effect"""
	var effect = TemporaryEffect.new(EffectType.Type.PUMP, effect_duration, source_data)
	effect.property_name = "power"
	if is_replacement:
		effect.modification_type = ModificationType.REPLACEMENT
		effect.replacement_value = power_change
	else:
		effect.modification_type = ModificationType.ADDITIVE
		effect.power_bonus = power_change
	return effect

static func create_ability_effect(ability: Dictionary, effect_duration: Duration, source_data: CardData = null) -> TemporaryEffect:
	"""Create a temporary ability grant effect (custom ability, not in EffectType yet)"""
	# Using ADD_KEYWORD as placeholder since there's no ABILITY type yet
	var effect = TemporaryEffect.new(EffectType.Type.ADD_KEYWORD, effect_duration, source_data)
	effect.granted_ability = ability
	return effect

## Helper methods

func set_source_card_data(card_data: CardData):
	"""Set the source CardData using WeakRef to avoid reference cycles"""
	if card_data:
		source_card_data = weakref(card_data)
	else:
		source_card_data = null

func get_source_card_data() -> CardData:
	"""Get the source CardData if it still exists, null otherwise"""
	if source_card_data:
		var data = source_card_data.get_ref()
		if data and is_instance_valid(data):
			return data
	return null

func get_source_card_name() -> String:
	"""Get the name of the source card (if it still exists)"""
	var card_data = get_source_card_data()
	return card_data.cardName if card_data else "Unknown"

func matches_type(type: EffectType.Type) -> bool:
	"""Check if this effect matches a specific type"""
	return effect_type == type

func matches_duration(check_duration: Duration) -> bool:
	"""Check if this effect matches a specific duration"""
	return duration == check_duration

func matches_keyword(keyword_name: String) -> bool:
	"""Check if this is a keyword effect with the specified keyword"""
	return effect_type == EffectType.Type.ADD_KEYWORD and keyword == keyword_name

func get_description() -> String:
	"""Get a human-readable description of this effect"""
	var desc = ""
	
	match effect_type:
		EffectType.Type.ADD_KEYWORD:
			desc = "Keyword: " + keyword
		EffectType.Type.ADD_TYPE:
			if type_to_add != "":
				desc = "Type: " + type_to_add
			else:
				desc = "Subtype: " + subtype_to_add
		EffectType.Type.PUMP:
			desc = "Power: " + ("+" if power_bonus >= 0 else "") + str(power_bonus)
		_:
			desc = "Effect: " + EffectType.type_to_string(effect_type)
	
	var duration_str = _get_duration_string()
	var source_name = get_source_card_name()
	if source_name != "Unknown":
		desc += " (from " + source_name + ", " + duration_str + ")"
	else:
		desc += " (" + duration_str + ")"
	
	return desc

func _get_duration_string() -> String:
	"""Get a string representation of the duration"""
	match duration:
		Duration.END_OF_TURN:
			return "until end of turn"
		Duration.END_OF_COMBAT:
			return "until end of combat"
		Duration.PERMANENT:
			return "permanent"
		Duration.CUSTOM:
			return "custom duration"
	return "unknown"




