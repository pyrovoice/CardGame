@tool
extends Node3D
class_name CombatZone

@onready var opponent_total_strength: Label3D = $OpponentTotalStrength
@onready var ally_total_strength: Label3D = $AllyTotalStrength
@onready var location_fill_opponent: LocationFill = $LocationFillOpponent
@onready var location_fill_player: LocationFill = $LocationFillPlayer
@onready var resolve_fight_button: ResolveFightButton = $Button
@onready var ally_side: GridContainer3D = $AllySide
@onready var opponent_side: GridContainer3D = $OpponentSide
@onready var ally_camp: GridContainer3D = $AllyCamp
@onready var opponent_camp: GridContainer3D = $OpponentCamp
@onready var lieutenant_hand: CardHand = $LieutenantHand
@onready var lieutenant_deck: Deck = $LieutenantDeck
@onready var floor_mesh: MeshInstance3D = $combatZone
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

## Overview mode shrinks the floor/collision width so all three locations fit on screen at once.
## Children (cards, camps, hand, deck, button) are intentionally left untouched for now.
const COMPACT_WIDTH_SCALE := 1.0 / 3.0
const _DEFAULT_RESIZE_DURATION := 0.35

## Editor toggle: preview the compact/expanded floor size directly in combat_zone.tscn
## (no need to open gameView.tscn's EditorPreviewHelper). Drives the same tween-based
## resize used at runtime by GameView.set_battlefield_focus().
@export var is_compact: bool = false:
	get:
		return _is_compact
	set(value):
		if not is_node_ready():
			# Deserializing a saved scene: @onready vars/base sizes don't exist yet.
			# Store the desired value; _ready() applies it once everything is set up.
			_is_compact = value
			return
		set_compact(value)

var _is_compact: bool = false
var _base_mesh_size: Vector2
var _base_collision_size: Vector3
var _resize_tween: Tween = null

func get_lieutenant_hand() -> CardHand:
	"""The hand belonging to the Lieutenant assigned to this location"""
	return lieutenant_hand

func get_lieutenant_deck() -> Deck:
	"""The deck belonging to the Lieutenant assigned to this location"""
	return lieutenant_deck

func get_ally_camp() -> GridContainer3D:
	"""The player's pre-combat staging area at this location"""
	return ally_camp

func get_opponent_camp() -> GridContainer3D:
	"""The opponent's pre-combat staging area at this location"""
	return opponent_camp

func set_location_highlight(active: bool) -> void:
	"""Simple yellow tint on the location floor to show it's a valid discounted drop target"""
	if not is_instance_valid(floor_mesh):
		return
	if active:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.2)
		floor_mesh.material_override = mat
	else:
		floor_mesh.material_override = null

func set_compact(compact: bool, duration: float = _DEFAULT_RESIZE_DURATION) -> void:
	"""Smoothly shrink (or restore) this zone's floor and collision width for the 3-battlefield overview.
	Safe to call every time set_battlefield_focus() runs - no-ops if already in that state."""
	if compact == _is_compact:
		return
	_is_compact = compact

	var scale_x := COMPACT_WIDTH_SCALE if compact else 1.0
	var target_mesh_width := _base_mesh_size.x * scale_x
	var target_collision_width := _base_collision_size.x * scale_x

	if _resize_tween and _resize_tween.is_valid():
		_resize_tween.kill()
	_resize_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	if floor_mesh.mesh is QuadMesh:
		_resize_tween.tween_property(floor_mesh.mesh, "size:x", target_mesh_width, duration)

	if collision_shape.shape is BoxShape3D:
		_resize_tween.tween_property(collision_shape.shape, "size:x", target_collision_width, duration)

func get_compact_width() -> float:
	"""Floor width this zone shrinks to when compact - i.e. the width of one third of the screen."""
	return _base_mesh_size.x * COMPACT_WIDTH_SCALE

func _ready() -> void:
	# Duplicate shared mesh/collision resources so resizing this zone doesn't affect its siblings
	# (all three CombatZone instances come from the same PackedScene sub-resources).
	if floor_mesh.mesh:
		floor_mesh.mesh = floor_mesh.mesh.duplicate()
		_base_mesh_size = (floor_mesh.mesh as QuadMesh).size
	if collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
		_base_collision_size = (collision_shape.shape as BoxShape3D).size

	# Apply any compact state saved on the scene (deserialized before base sizes existed above)
	if _is_compact:
		var pending_compact := _is_compact
		_is_compact = false
		set_compact(pending_compact, 0.0)

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

func _place_in_grid(card: Card, target_container: GridContainer3D) -> void:
	if not card or not is_instance_valid(card):
		push_error("CombatZone._place_in_grid: card is null or invalid")
		return
	if not is_instance_valid(target_container):
		push_error("CombatZone._place_in_grid: Target container is invalid")
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

func set_card(card: Card, _target_position: int = -1) -> void:
	"""Add a card to the active combat grid (fighting side). Cards are automatically arranged by GridContainer3D"""
	if not card or not is_instance_valid(card) or not card.cardData or not is_instance_valid(card.cardData):
		push_error("CombatZone.set_card: card has no valid cardData")
		return

	var ally_team: bool = card.cardData.playerControlled
	_place_in_grid(card, ally_side if ally_team else opponent_side)

func place_in_camp(card: Card) -> void:
	"""Add a card to the pre-combat Camp for its controller's side at this location"""
	if not card or not is_instance_valid(card) or not card.cardData or not is_instance_valid(card.cardData):
		push_error("CombatZone.place_in_camp: card has no valid cardData")
		return

	var ally_team: bool = card.cardData.playerControlled
	_place_in_grid(card, ally_camp if ally_team else opponent_camp)

func update_resolve_fight_display(is_resolved: bool):
	"""Update the appearance of the resolve fight label based on resolution status"""
	resolve_fight_button.set_ready(is_resolved)
