extends Node3D
class_name LocationFill

@onready var control: FlexibleProgressBar = $Sprite3D/SubViewport/Control

@export var isPlayer = true

func setup_capture_bar(currentValue: SignalInt, maxValue: SignalInt):
	"""Setup the capture bar with the GameData values"""
	if !isPlayer:
		control.material.set_shader_parameter("fluid_shadow_color", Color(2.613, 0.0, 0.15))
	currentValue.value_changed.connect(setCurrentValue)
	maxValue.value_changed.connect(setMaximum)
	# Set initial values
	setMaximum(maxValue.getValue())
	setCurrentValue(currentValue.getValue())
	
func setMaximum(new_value: int, old_value: int = 0):
	"""Update maximum value (called by SignalInt.value_changed)"""
	if control:
		control.set_max_value(new_value)
		control.material.set_shader_parameter("segment_count", new_value)

func setCurrentValue(new_value: int, old_value: int = 0):
	"""Update current value (called by SignalInt.value_changed)"""
	if control:
		control.set_bar_value(new_value)
