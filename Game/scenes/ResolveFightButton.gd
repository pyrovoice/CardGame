extends Area3D
class_name ResolveFightButton

@onready var resolve_fight: Label3D = $ResolveFight

func set_ready(b: bool):
	if b:
		resolve_fight.text = "DONE"
		resolve_fight.modulate = Color.GREEN
	else:
		resolve_fight.text = "FIGHT"
		resolve_fight.modulate = Color.WHITE
