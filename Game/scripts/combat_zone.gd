extends Node3D
class_name CombatZone

@onready var opponent_total_strength: Label3D = $OpponentTotalStrength
@onready var ally_total_strength: Label3D = $AllyTotalStrength
@onready var resolve_fight_label: Label3D = $ResolveFight
var ennemySpots: Array[CombatantFightingSpot] = []
var allySpots: Array[CombatantFightingSpot] = []
@onready var location_fill_opponent: Node3D = $LocationFillOpponent
@onready var location_fill_player: Node3D = $LocationFillPlayer

func _ready() -> void:
	for i in range(1, 4):
		for y in ["AllySpot", "EnnemySpot"]:
			var arr = allySpots if y == "AllySpot" else ennemySpots
			var c: CombatantFightingSpot = find_child(y+str(i))
			c.onCardEnteredOrLeft.connect(_on_child_change)
			arr.push_back(c)
	
func _on_child_change():
	# Don't update if we're being destroyed or not in the tree
	if not is_inside_tree() or is_queued_for_deletion():
		return
		
	# Check if the UI elements are still valid before updating them
	if is_instance_valid(ally_total_strength):
		ally_total_strength.text = str(getTotalStrengthForSide(true))
	if is_instance_valid(opponent_total_strength):
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
		# Check if the CombatantFightingSpot itself is valid
		if not is_instance_valid(c):
			continue
			
		var card = c.getCard()
		# Check both null and valid instance
		if card != null and is_instance_valid(card) and is_instance_valid(card.cardData):
			total += card.cardData.power
	return total

func getCardSlot(i: int , allyTeam: bool) -> CombatantFightingSpot:
	var side = "AllySpot" if allyTeam else "EnnemySpot"
	var spot = find_child(side + str(i))
	return spot

func update_resolve_fight_display(is_resolved: bool):
	"""Update the appearance of the resolve fight label based on resolution status"""
	if resolve_fight_label:
		if is_resolved:
			resolve_fight_label.text = "DONE"
			resolve_fight_label.modulate = Color.GREEN
		else:
			resolve_fight_label.text = "FIGHT"
			resolve_fight_label.modulate = Color.WHITE
