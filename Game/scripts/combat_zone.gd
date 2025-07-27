extends Node3D
class_name CombatZone

@onready var ally_container: GridContainer3D = $allyContainer
@onready var opponent_container: GridContainer3D = $opponentContainer
@onready var opponent_total_strength: Label3D = $OpponentTotalStrength
@onready var ally_total_strength: Label3D = $AllyTotalStrength

func _ready() -> void:
	getZone(true).child_entered_tree.connect(_on_child_change)
	getZone(false).child_exiting_tree.connect(_on_child_change)
	
func getZone(playerZone: bool) -> GridContainer3D:
	return ally_container if playerZone else opponent_container

func _on_child_change(child: Node):
	ally_total_strength.text = str(getTotalStrengthForSide(true))
	opponent_total_strength.text = str(getTotalStrengthForSide(false))
	
func getTotalStrengthForSide(playerSide: bool):
	var totalAllies = 0
	for c: Card in getZone(true if playerSide else false).get_children():
		totalAllies += c.getPower()
	return totalAllies
