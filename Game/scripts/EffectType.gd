extends RefCounted
class_name EffectType

# Unified enum for all effect types in the game
enum Type {
	# Spell effects
	DEAL_DAMAGE,  # Deal damage to target(s)
	PUMP,  # Temporarily boost creature power
	DRAW,  # Draw cards
	
	# Token/creature effects
	CREATE_TOKEN,  # Create token creatures
	CAST,  # Cast/play a card from any zone
	
	# Modification effects
	ADD_TYPE,  # Add types/subtypes to cards
	ADD_KEYWORD,  # Grant keyword abilities (used by PumpAll)
	
	# Future effects
	DESTROY,  # Destroy permanents
	BOUNCE,  # Return to hand
	EXILE,  # Exile cards
	MILL,  # Mill cards from deck
	DISCARD,  # Discard cards
	SEARCH,  # Search library
	SHUFFLE,  # Shuffle deck
}

# Convert effect type enum to string representation (for display/debugging)
static func type_to_string(effect_type: Type) -> String:
	match effect_type:
		Type.DEAL_DAMAGE:
			return "DealDamage"
		Type.PUMP:
			return "Pump"
		Type.DRAW:
			return "Draw"
		Type.CREATE_TOKEN:
			return "CreateToken"
		Type.CAST:
			return "Cast"
		Type.ADD_TYPE:
			return "AddType"
		Type.ADD_KEYWORD:
			return "AddKeyword"
		Type.DESTROY:
			return "Destroy"
		Type.BOUNCE:
			return "Bounce"
		Type.EXILE:
			return "Exile"
		Type.MILL:
			return "Mill"
		Type.DISCARD:
			return "Discard"
		Type.SEARCH:
			return "Search"
		Type.SHUFFLE:
			return "Shuffle"
		_:
			return "UNKNOWN"

# Convert string representation to effect type enum
static func string_to_type(effect_string: String) -> Type:
	match effect_string:
		"DealDamage":
			return Type.DEAL_DAMAGE
		"Pump":
			return Type.PUMP
		"Draw":
			return Type.DRAW
		"CreateToken":
			return Type.CREATE_TOKEN
		"Cast":
			return Type.CAST
		"AddType":
			return Type.ADD_TYPE
		"AddKeyword", "PumpAll":  # PumpAll is alias for AddKeyword
			return Type.ADD_KEYWORD
		"Destroy":
			return Type.DESTROY
		"Bounce":
			return Type.BOUNCE
		"Exile":
			return Type.EXILE
		"Mill":
			return Type.MILL
		"Discard":
			return Type.DISCARD
		"Search":
			return Type.SEARCH
		"Shuffle":
			return Type.SHUFFLE
		_:
			push_error("Unknown effect type string: " + effect_string + " - Please update card definitions to use modern format")
			return Type.DRAW  # Default fallback

# Get all available effect type strings
static func get_all_strings() -> Array[String]:
	return [
		"DealDamage", "Pump", "Draw", "CreateToken", "Cast", "AddType", 
		"AddKeyword", "Destroy", "Bounce", "Exile", "Mill", 
		"Discard", "Search", "Shuffle"
	]

# Check if an effect type requires targeting
static func requires_targeting(effect_type: Type) -> bool:
	match effect_type:
		Type.DEAL_DAMAGE, Type.PUMP, Type.DESTROY, Type.BOUNCE, Type.EXILE:
			return true
		_:
			return false

# Check if an effect type is a spell effect
static func is_spell_effect(effect_type: Type) -> bool:
	match effect_type:
		Type.DEAL_DAMAGE, Type.PUMP, Type.DRAW, Type.DESTROY, Type.BOUNCE, Type.EXILE, Type.MILL, Type.DISCARD:
			return true
		_:
			return false

# Check if an effect type is a triggered ability effect
static func is_triggered_effect(effect_type: Type) -> bool:
	match effect_type:
		Type.CREATE_TOKEN, Type.DRAW, Type.ADD_TYPE, Type.ADD_KEYWORD:
			return true
		_:
			return false
