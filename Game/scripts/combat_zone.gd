extends Node3D
class_name CombatZone

@onready var opponent_total_strength: Label3D = $OpponentTotalStrength
@onready var ally_total_strength: Label3D = $AllyTotalStrength
@onready var location_fill_opponent: LocationFill = $LocationFillOpponent
@onready var location_fill_player: LocationFill = $LocationFillPlayer
@onready var resolve_fight_button: ResolveFightButton = $Button
@onready var ally_side: GridContainer3D = $AllySide
@onready var opponent_side: GridContainer3D = $OpponentSide

func _ready() -> void:
	# Connect to child changes for both sides
	ally_side.child_entered_tree.connect(_on_child_change)
	ally_side.child_exiting_tree.connect(_on_child_change)
	opponent_side.child_entered_tree.connect(_on_child_change)
	opponent_side.child_exiting_tree.connect(_on_child_change)
	
func _on_child_change(_node = null):
	# Don't update if we're being destroyed or not in the tree
	if not is_inside_tree() or is_queued_for_deletion():
		return
		
	# Check if the UI elements are still valid before updating them
	if is_instance_valid(ally_total_strength):
		ally_total_strength.text = str(getTotalStrengthForSide(true))
	if is_instance_valid(opponent_total_strength):
		opponent_total_strength.text = str(getTotalStrengthForSide(false))

func getFirstEmptyLocation(playerSide: bool) -> GridContainer3D:
	"""Returns the GridContainer3D for the specified side to add cards to"""
	return ally_side if playerSide else opponent_side
	
func getTotalStrengthForSide(playerSide: bool):
	var total = 0
	var container = ally_side if playerSide else opponent_side
	
	if not is_instance_valid(container):
		return 0
	
	for child in container.get_children():
		# Check if child is a valid Card instance
		if child is Card and is_instance_valid(child) and is_instance_valid(child.cardData):
			total += child.cardData.power
	
	return total

func set_card(card: Card, target_position: int = -1) -> void:
	"""Add a card to the combat zone. Cards are automatically arranged by GridContainer3D"""
	if not card or not is_instance_valid(card):
		push_error("CombatZone.set_card: card is null or invalid")
		return
	if not card.cardData or not is_instance_valid(card.cardData):
		push_error("CombatZone.set_card: card has no valid cardData")
		return

	var ally_team: bool = card.cardData.playerControlled
	var target_container = ally_side if ally_team else opponent_side
	
	if not is_instance_valid(target_container):
		push_error("CombatZone.set_card: Target container is invalid")
		return
	
	# Reparent without triggering auto-reorganize (child_entered_tree not connected)
	# false = don't preserve global transform, so no compensating local scale is baked in.
	# Cards inherit the zone's scale naturally (Option A sizing).
	if card.get_parent():
		card.reparent(target_container, false)
	else:
		target_container.add_child(card)
	
	# Reorganize explicitly: sets all card positions without moving representations
	target_container.reorganize(card)

func update_resolve_fight_display(is_resolved: bool):
	"""Update the appearance of the resolve fight label based on resolution status"""
	resolve_fight_button.set_ready(is_resolved)
