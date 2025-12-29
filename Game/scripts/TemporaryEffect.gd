class_name TemporaryEffect extends RefCounted

## Represents a temporary effect applied to a card
## Used for tracking effects that expire (EndOfTurn, EndOfCombat, etc.)

enum Duration {
	END_OF_TURN,
	END_OF_COMBAT,
	PERMANENT,    # Doesn't expire (until explicitly removed)
	CUSTOM        # Custom duration logic
}

var effect_type: EffectType.Type
var duration: Duration
var source_card_data: WeakRef  # Weak reference to the CardData that granted this effect

# Type-specific data
var keyword: String = ""           # For ADD_KEYWORD type
var type_to_add: String = ""       # For ADD_TYPE type
var subtype_to_add: String = ""    # For ADD_TYPE type (subtype)
var power_bonus: int = 0           # For PUMP type
var granted_ability: Dictionary = {}  # For ABILITY type (if we add it later)

func _init(p_effect_type: EffectType.Type, p_duration: Duration, p_source_data: CardData = null):
	effect_type = p_effect_type
	duration = p_duration
	set_source_card_data(p_source_data)

## Factory methods for creating specific effect types

static func create_keyword_effect(keyword_name: String, effect_duration: Duration, source_data: CardData = null) -> TemporaryEffect:
	"""Create a temporary keyword effect (e.g., Spellshield, Flying)"""
	var effect = TemporaryEffect.new(EffectType.Type.ADD_KEYWORD, effect_duration, source_data)
	effect.keyword = keyword_name
	return effect

static func create_type_effect(type_name: String, is_subtype: bool, effect_duration: Duration, source_data: CardData = null) -> TemporaryEffect:
	"""Create a temporary type/subtype effect"""
	var effect = TemporaryEffect.new(EffectType.Type.ADD_TYPE, effect_duration, source_data)
	if is_subtype:
		effect.subtype_to_add = type_name
	else:
		effect.type_to_add = type_name
	return effect

static func create_power_boost_effect(power_change: int, effect_duration: Duration, source_data: CardData = null) -> TemporaryEffect:
	"""Create a temporary power boost effect"""
	var effect = TemporaryEffect.new(EffectType.Type.PUMP, effect_duration, source_data)
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

## Conversion methods for backward compatibility with Dictionary format

func to_dictionary() -> Dictionary:
	"""Convert to dictionary format for backward compatibility"""
	var dict = {
		"effect_type": effect_type,
		"duration": _duration_enum_to_string(duration),
		"source": get_source_card_name()
	}
	
	match effect_type:
		EffectType.Type.ADD_KEYWORD:
			dict["type"] = "keyword"
			dict["keyword"] = keyword
		EffectType.Type.ADD_TYPE:
			dict["type"] = "type"
			if type_to_add != "":
				dict["type_to_add"] = type_to_add
			else:
				dict["type_to_remove"] = subtype_to_add  # Legacy naming
		EffectType.Type.PUMP:
			dict["type"] = "power_boost"
			dict["power_bonus"] = power_bonus
		_:
			dict["type"] = "unknown"
	
	return dict

static func from_dictionary(dict: Dictionary, source_card_data: CardData = null) -> TemporaryEffect:
	"""Create a TemporaryEffect from dictionary format (for backward compatibility)
	Note: source_card_data should be provided if available, otherwise source is lost"""
	var type_str = dict.get("type", "")
	var effect_type_enum: EffectType.Type
	
	match type_str:
		"keyword":
			effect_type_enum = EffectType.Type.ADD_KEYWORD
		"type":
			effect_type_enum = EffectType.Type.ADD_TYPE
		"power_boost":
			effect_type_enum = EffectType.Type.PUMP
		"ability":
			effect_type_enum = EffectType.Type.ADD_KEYWORD  # No ABILITY type yet
		_:
			effect_type_enum = EffectType.Type.ADD_KEYWORD
	
	var duration_str = dict.get("duration", "EndOfTurn")
	var duration_enum = _string_to_duration_enum(duration_str)
	
	var effect = TemporaryEffect.new(effect_type_enum, duration_enum, source_card_data)
	
	# Set type-specific data
	match effect_type_enum:
		EffectType.Type.ADD_KEYWORD:
			effect.keyword = dict.get("keyword", "")
		EffectType.Type.ADD_TYPE:
			effect.type_to_add = dict.get("type_to_add", "")
			effect.subtype_to_add = dict.get("type_to_remove", "")  # Legacy naming
		EffectType.Type.PUMP:
			effect.power_bonus = dict.get("power_bonus", 0)
	
	return effect

static func _duration_enum_to_string(duration_enum: Duration) -> String:
	"""Convert duration enum to string"""
	match duration_enum:
		Duration.END_OF_TURN:
			return "EndOfTurn"
		Duration.END_OF_COMBAT:
			return "EndOfCombat"
		Duration.PERMANENT:
			return "Permanent"
		Duration.CUSTOM:
			return "Custom"
	return "EndOfTurn"

static func _string_to_duration_enum(duration_str: String) -> Duration:
	"""Convert string to duration enum"""
	match duration_str:
		"EndOfTurn":
			return Duration.END_OF_TURN
		"EndOfCombat":
			return Duration.END_OF_COMBAT
		"Permanent":
			return Duration.PERMANENT
		"Custom":
			return Duration.CUSTOM
	return Duration.END_OF_TURN
