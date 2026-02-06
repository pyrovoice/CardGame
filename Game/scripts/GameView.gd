extends Node
class_name GameView

## GameView - View Layer for Card Game
##
## Manages all visual representations (Card nodes, animations, scene tree)
## Responds to controller (Game) commands to update visuals based on model (GameData)
##
## Responsibilities:
## - Create/destroy Card node views
## - Animate card movements
## - Manage Card node positions in zone containers
## - Handle visual effects and transitions
##
## Does NOT:
## - Make game logic decisions
## - Modify GameData directly
## - Handle input (that's Game's job via PlayerControl)

# Zone container references
var player_hand: CardHand
var extra_hand: CardHand
var opponent_hand: CardHand
var player_base: PlayerBase
var deck: Deck
var deck_opponent: Deck
var extra_deck: CardContainer
var graveyard: Graveyard
var graveyard_opponent: Graveyard
var combat_zones: Array[CombatZone] = []

# Card node tracking - maps CardData to Card view
var card_data_to_view: Dictionary = {}  # CardData -> Card

# Scene references
const CARD_SCENE = preload("res://Game/scenes/Card.tscn")

func _init():
	pass

## Initialize view with zone container references
func setup(
	_player_hand: CardHand,
	_extra_hand: CardHand,
	_opponent_hand: CardHand,
	_player_base: PlayerBase,
	_deck: Deck,
	_deck_opponent: Deck,
	_extra_deck: CardContainer,
	_graveyard: Graveyard,
	_graveyard_opponent: Graveyard,
	_combat_zones: Array[CombatZone]
) -> void:
	player_hand = _player_hand
	extra_hand = _extra_hand
	opponent_hand = _opponent_hand
	player_base = _player_base
	deck = _deck
	deck_opponent = _deck_opponent
	extra_deck = _extra_deck
	graveyard = _graveyard
	graveyard_opponent = _graveyard_opponent
	combat_zones = _combat_zones

## Create a Card view node for the given CardData
func create_card_view(card_data: CardData, is_player_controlled: bool, is_token: bool = false) -> Card:
	var card: Card = CARD_SCENE.instantiate()
	card.cardData = card_data
	card.is_player_controlled = is_player_controlled
	
	# Track this view
	card_data_to_view[card_data] = card
	
	return card

## Get the Card view for a CardData (if it exists)
func get_card_view(card_data: CardData) -> Card:
	return card_data_to_view.get(card_data, null)

## Remove a Card view from tracking (before freeing)
func remove_card_view(card_data: CardData) -> void:
	if card_data_to_view.has(card_data):
		card_data_to_view.erase(card_data)

## Get zone container node from GameZone.e enum
func get_zone_container(zone: GameZone.e) -> Node:
	match zone:
		GameZone.e.HAND_PLAYER:
			return player_hand
		GameZone.e.HAND_OPPONENT:
			return opponent_hand
		GameZone.e.BATTLEFIELD_PLAYER:
			return player_base
		GameZone.e.BATTLEFIELD_OPPONENT:
			return player_base  # Both use same PlayerBase for now
		GameZone.e.GRAVEYARD_PLAYER:
			return graveyard
		GameZone.e.GRAVEYARD_OPPONENT:
			return graveyard_opponent
		GameZone.e.DECK_PLAYER:
			return deck
		GameZone.e.DECK_OPPONENT:
			return deck_opponent
		GameZone.e.EXTRA_DECK_PLAYER:
			return extra_deck
		GameZone.e.COMBAT_PLAYER, GameZone.e.COMBAT_OPPONENT:
			# Combat zones handled via card_to_combat_spot in GameData
			return null
		_:
			push_error("GameView.get_zone_container: Unknown zone: " + str(zone))
			return null

## Animate card draw from deck to hand
func animate_draw_card(card_data: CardData, deck_position: Vector3, hand_position: Vector3, delay: float = 0.0, should_flip: bool = true) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.animate_draw_card: No view exists for card")
		return
	
	var draw_position = Vector3(0, 2, 1)
	var animator = card.getAnimator()
	
	animator.draw_card(
		deck_position,
		draw_position,
		hand_position,
		delay,
		should_flip
	)
	
	await card.get_tree().create_timer(delay + 0.6).timeout

## Animate card entering battlefield
func animate_card_to_battlefield(card_data: CardData, target_position: Vector3, parent: Node) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.animate_card_to_battlefield: No view exists for card")
		return
	
	# Set visual properties
	card.setFlip(true)
	card.getAnimator().make_small()
	
	# Reparent to battlefield container
	GameUtility.reparentCardWithoutMovingRepresentation(card, parent)
	
	# Animate to target position
	var local_target = target_position + Vector3(0, 0.2, 0)
	var tween = card.getAnimator().move_to_position(local_target, 0.8, parent)
	if tween:
		await tween.finished

## Animate card to graveyard
func animate_card_to_graveyard(card_data: CardData, graveyard_position: Vector3) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.animate_card_to_graveyard: No view exists for card")
		return
	
	var tween = card.getAnimator().move_to_position(graveyard_position, 0.5)
	if tween:
		await tween.finished

## Animate card to combat zone
func animate_card_to_combat(card_data: CardData, combat_spot: CombatantFightingSpot) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.animate_card_to_combat: No view exists for card")
		return
	
	# CombatantFightingSpot.setCard handles the animation
	combat_spot.setCard(card)

## Animate card back to base from combat
func animate_card_to_base(card_data: CardData, base_position: Vector3, parent: Node) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.animate_card_to_base: No view exists for card")
		return
	
	var local_target = base_position + Vector3(0, 0.2, 0)
	var tween = card.getAnimator().move_to_position(local_target, 0.8, parent)
	if tween:
		await tween.finished

## Generic card movement animation
func animate_card_move(card_data: CardData, target_position: Vector3, duration: float = 0.5) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.animate_card_move: No view exists for card")
		return
	
	card.setFlip(true)
	var tween = card.getAnimator().move_to_position(target_position, duration)
	if tween:
		await tween.finished

## Move card view to appropriate zone container (reparent in scene tree)
func move_card_view_to_zone(card_data: CardData, zone: GameZone.e) -> void:
	var card = get_card_view(card_data)
	if not card:
		push_error("GameView.move_card_view_to_zone: No view exists for card")
		return
	
	var zone_container = get_zone_container(zone)
	if not zone_container:
		return
	
	# Reparent without moving visual position
	GameUtility.reparentCardWithoutMovingRepresentation(card, zone_container)

## Destroy a card view and clean up
func destroy_card_view(card_data: CardData) -> void:
	var card = get_card_view(card_data)
	if not card:
		return
	
	# Remove from parent immediately
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	# Clean up tracking
	remove_card_view(card_data)
	
	# Queue for deletion
	card.queue_free()

## Update hand arrangement
func arrange_hand(hand_zone: CardHand, cards: Array[Card] = []) -> void:
	if cards.is_empty():
		hand_zone.arrange_cards_fan()
	else:
		hand_zone.arrange_cards_fan(cards)
