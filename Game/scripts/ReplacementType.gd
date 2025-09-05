extends RefCounted
class_name ReplacementType

# Unified enum for all replacement effect types in the game
enum Type {
	CREATE_TOKEN  # Replaces token creation effects
}

# Convert replacement type enum to string representation
static func type_to_string(replacement_type: Type) -> String:
	match replacement_type:
		Type.CREATE_TOKEN:
			return "CreateToken"
		_:
			return "UNKNOWN"

# Convert string representation to replacement type enum
static func string_to_type(replacement_string: String) -> Type:
	match replacement_string:
		"CreateToken":
			return Type.CREATE_TOKEN
		_:
			push_warning("Unknown replacement type string: " + replacement_string)
			return Type.CREATE_TOKEN  # Default fallback

# Get all available replacement type strings
static func get_all_strings() -> Array[String]:
	return ["CreateToken"]

# Check if a replacement type handles token creation
static func is_token_creation(replacement_type: Type) -> bool:
	return replacement_type == Type.CREATE_TOKEN

# Get the effect name/identifier used in card files
static func get_event_identifier(replacement_type: Type) -> String:
	return type_to_string(replacement_type)
