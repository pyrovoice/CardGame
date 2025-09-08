extends RefCounted
class_name SignalFloat

# The actual value storage
var _value: float = 0.0
# Signal emitted when value changes
signal value_changed(new_value: float, old_value: float)

# Property with custom setter
var value: float:
	get:
		return _value
	set(new_value):
		setValue(new_value)

func _init(initial_value: float = 0.0):
	_value = initial_value

func setValue(new_value: float):
	"""Custom function called whenever value is set"""
	var old_value = _value
	_value = new_value
	# Emit signal when value changes
	if old_value != new_value:
		value_changed.emit(new_value, old_value)

func getValue() -> float:
	return _value

# Optional: Add operators for convenience
func _add(other):
	if other is SignalFloat:
		return _value + other._value
	else:
		return _value + other

func _sub(other):
	if other is SignalFloat:
		return _value - other._value
	else:
		return _value - other

func getText() -> String:
	return str(_value)
