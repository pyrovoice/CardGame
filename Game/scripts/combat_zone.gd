extends Node3D
class_name CombatZone

@onready var ally_container: GridContainer3D = $allyContainer
@onready var opponent_container: GridContainer3D = $opponentContainer
@onready var opponent_total_strength: Label3D = $OpponentTotalStrength
@onready var ally_total_strength: Label3D = $AllyTotalStrength
var ennemySpots = []
var allySpots = []

func _ready() -> void:
	for i in range(1, 4):
		for y in ["AllySpot", "EnnemySpot"]:
			var arr = allySpots if y == "AllySpot" else ennemySpots
			var c: CombatantFightingSpot = find_child(y+str(i))
			c.onCardEnteredOrLeft.connect(_on_child_change)
			arr.push_back(c)
	
func _on_child_change(child: Node):
	ally_total_strength.text = str(getTotalStrengthForSide(true))
	opponent_total_strength.text = str(getTotalStrengthForSide(false))

func getFirstEmptyLocation(playerSide: bool) -> CombatantFightingSpot:
	var sideArray = allySpots if playerSide else ennemySpots
	var filtered =  sideArray.filter(func(c:CombatantFightingSpot): return c.getCard() == null)
	if filtered && filtered.size() > 0:
		return filtered[0]
	return null
	
func getTotalStrengthForSide(playerSide: bool):
	var total = 0
	var sideArray = allySpots if playerSide else ennemySpots
	for c: CombatantFightingSpot in sideArray:
		var card = c.getCard()
		total += 0 if card == null else card.cardData.power
	return total
