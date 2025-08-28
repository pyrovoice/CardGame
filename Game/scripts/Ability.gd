extends RefCounted
class_name Ability

# Base class for all card abilities

var description: String = ""

func _init(_description: String = ""):
	description = _description

func execute(_card: Card, _game_context: Node):
	# Base implementation - to be overridden by subclasses
	push_error("Ability.execute() must be implemented by subclass")

func describe() -> String:
	return "Ability: " + description
