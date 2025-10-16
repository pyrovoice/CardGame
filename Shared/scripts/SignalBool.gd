extends Node
class_name SignalBool

# The actual value storage
var _value: bool
# Signal emitted when value changes
signal value_changed(new_value: bool)

# Property with custom setter
var value: bool:
	get:
		return _value
	set(new_value):
		setValue(new_value)

func _init(initial_value: bool = false):
	_value = initial_value

func setValue(new_value: bool):
	"""Custom function called whenever value is set"""
	var old_value = _value
	_value = new_value
	# Emit signal when value changes
	if old_value != new_value:
		value_changed.emit(new_value)

func getValue() -> bool:
	return _value

func getText() -> String:
	return str(_value)
