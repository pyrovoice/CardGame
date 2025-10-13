extends RefCounted
class_name SignalInt

# The actual value storage
var _value: int = 0
# Signal emitted when value changes
signal value_changed(new_value: int, old_value: int)

# Property with custom setter
var value: int:
	get:
		return _value
	set(new_value):
		setValue(new_value)

func _init(initial_value: int = 0):
	_value = initial_value

func setValue(new_value: int):
	"""Custom function called whenever value is set"""
	var old_value = _value
	_value = new_value
	# Emit signal when value changes
	if old_value != new_value:
		value_changed.emit(new_value, old_value)

func getValue() -> int:
	return _value

# Optional: Add operators for convenience
func _add(other):
	if other is SignalInt:
		return _value + other._value
	else:
		return _value + other

func _sub(other):
	if other is SignalInt:
		return _value - other._value
	else:
		return _value - other

func getText() -> String:
	return str(_value)
