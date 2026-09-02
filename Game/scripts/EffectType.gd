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
	CREATE_CARD,  # Create a card from a pool into hand
	CAST,  # Cast/play a card from any zone
	CREATE_DELAYED_EFFECT,  # Create a delayed/orphaned effect that triggers at a specific time
	
	# Modification effects
	ADD_TYPE,  # Add types/subtypes to cards
	ADD_KEYWORD,  # Grant keyword abilities (used by PumpAll)
	
	# Card movement effects
	MOVE_CARD,  # Move card from one zone to another
	SWITCH_POSITIONS,  # Switch positions between two cards (Elusive)
	SACRIFICE,  # Sacrifice permanents (move to owner's graveyard)
	REMOVE_CARD_FROM_PLAY,  # Completely remove a card from the game (not to any zone)
	
	# Relic mechanics
	RELIC_DURABILITY_TICK,  # Decrement relic durability; sacrifice at zero
	
	# State-based event that can be intercepted by replacement effects
	DEATH,  # A permanent would die (move from battlefield to graveyard)
	
	# Draft effects
	DRAFT,  # Draft a card from an archetype pool to hand

	# Resource effects
	ADD_GOLD,  # Add gold to the controlling player
	
	# Recycle mechanic
	RECYCLE,  # Exile X cards from graveyard at random (optional or mandatory)
	REDUCE_COST,  # Reduce a card's gold cost by N

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
		Type.CREATE_CARD:
			return "CreateCard"
		Type.CAST:
			return "Cast"
		Type.CREATE_DELAYED_EFFECT:
			return "CreateDelayedEffect"
		Type.ADD_TYPE:
			return "AddType"
		Type.ADD_KEYWORD:
			return "AddKeyword"
		Type.MOVE_CARD:
			return "MoveCard"
		Type.SWITCH_POSITIONS:
			return "SwitchPositions"
		Type.SACRIFICE:
			return "Sacrifice"
		Type.REMOVE_CARD_FROM_PLAY:
			return "RemoveCardFromPlay"
		Type.RELIC_DURABILITY_TICK:
			return "RelicDurabilityTick"
		Type.DEATH:
			return "Death"
		Type.DRAFT:
			return "Draft"
		Type.ADD_GOLD:
			return "AddGold"
		Type.RECYCLE:
			return "Recycle"
		Type.REDUCE_COST:
			return "ReduceCost"
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
		"CreateCard":
			return Type.CREATE_CARD
		"Cast":
			return Type.CAST
		"CreateDelayedEffect":
			return Type.CREATE_DELAYED_EFFECT
		"AddType":
			return Type.ADD_TYPE
		"AddKeyword", "PumpAll":  # PumpAll is alias for AddKeyword
			return Type.ADD_KEYWORD
		"MoveCard":
			return Type.MOVE_CARD
		"SwitchPositions":
			return Type.SWITCH_POSITIONS
		"Sacrifice":
			return Type.SACRIFICE
		"RemoveCardFromPlay":
			return Type.REMOVE_CARD_FROM_PLAY
		"RelicDurabilityTick":
			return Type.RELIC_DURABILITY_TICK
		"Death":
			return Type.DEATH
		"Draft":
			return Type.DRAFT
		"AddGold":
			return Type.ADD_GOLD
		"Recycle":
			return Type.RECYCLE
		"ReduceCost":
			return Type.REDUCE_COST
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
			return Type.NONE  # Unknown string — caller should check with is_valid_string first

# Check if a string is a valid effect type (without emitting errors)
static func is_valid_string(s: String) -> bool:
	return string_to_type(s) != Type.NONE

# Get all available effect type strings
static func get_all_strings() -> Array[String]:
	return [
		"DealDamage", "Pump", "Draw", "CreateToken", "CreateCard", "Cast", "AddType", 
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
