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
	
	# Card movement effects
	MOVE_CARD,  # Move card from one zone to another
	SWITCH_POSITIONS,  # Switch positions between two cards (Elusive)
	
	# Future effects
	DESTROY,  # Destroy permanents
	BOUNCE,  # Return to hand
	EXILE,  # Exile cards
	MILL,  # Mill cards from deck
	DISCARD,  # Discard cards
	SEARCH,  # Search library
	SHUFFLE,  # Shuffle deck
	NONE
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
		Type.MOVE_CARD:
			return "MoveCard"
		Type.SWITCH_POSITIONS:
			return "SwitchPositions"
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
	# Strip whitespace and normalize to handle variations
	var normalized = effect_string.strip_edges()
	
	match normalized:
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
		"MoveCard":
			return Type.MOVE_CARD
		"SwitchPositions":
			return Type.SWITCH_POSITIONS
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
			push_error("❌ UNKNOWN EFFECT TYPE: '" + normalized + "' (original: '" + effect_string + "') - Check card definition. Defaulting to DRAW.")
			push_error("   Available types: " + str(get_all_strings()))
			return Type.DRAW  # Default fallback

# Get all available effect type strings
static func get_all_strings() -> Array[String]:
	return [
		"DealDamage", "Pump", "Draw", "CreateToken", "Cast", "AddType", 
		"AddKeyword", "MoveCard", "SwitchPositions", "Destroy", "Bounce", "Exile", "Mill", 
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
