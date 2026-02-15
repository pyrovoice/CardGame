extends Node3D
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

# UI references
var game_ui: GameUI
var draw_button: Button
var admin_button: Button
var alternative_cast_choice: Control
var admin_scene: AdminConsole

# Headless mode - skips all animations and visual updates
var headless: bool = false

const CARD_SCENE = preload("res://Game/scenes/Card.tscn")

func _init():
	pass

## Initialize view by finding all child nodes from itself
func setup(is_headless: bool = false) -> void:
	headless = is_headless
	# Find zone containers (all children of GameView node)
	player_hand = get_node("PlayerHand")
	extra_hand = get_node("ExtraHand")
	opponent_hand = get_node("OpponentHand")
	player_base = get_node("playerBase")
	deck = get_node("Deck")
	deck_opponent = get_node("DeckOpponent")
	extra_deck = get_node("extraDeck")
	graveyard = get_node("graveyard")
	graveyard_opponent = get_node("graveyardOpponent")
	
	# Combat zones
	combat_zones = [
		get_node("combatZone"),
		get_node("combatZone2"),
		get_node("combatZone3")
	]
	
	# UI references
	game_ui = get_node("UI")
	draw_button = game_ui.get_node("draw")
	admin_button = game_ui.get_node("AdminButton")
	alternative_cast_choice = game_ui.get_node("AlternativeCastChoice")
	admin_scene = game_ui.get_node("AdminScene")

## Create a Card view node for the given CardData
func create_card_view(card_data: CardData, is_player_controlled: bool, is_token: bool = false) -> Card:
	var card: Card = CARD_SCENE.instantiate()
	card.cardData = card_data
	card.is_player_controlled = is_player_controlled
	
	return card

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
	if headless:
		return
	
	var card = card_data.get_card_object()
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

## Animate card from deck to hand (complete flow)
func animate_deck_to_hand(card_data: CardData, dest_zone: GameZone.e) -> void:
	"""Complete deck-to-hand animation: creates card view, animates draw, arranges hand"""
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		push_error("GameView.animate_deck_to_hand: No view exists for card")
		return
	
	# Get destination hand container
	var dest_hand = get_zone_container(dest_zone)
	if not dest_hand or not dest_hand is CardHand:
		push_error("GameView.animate_deck_to_hand: Invalid hand container")
		return
	
	# Get deck position for animation origin
	var deck_container = deck if dest_zone == GameZone.e.HAND_PLAYER else deck_opponent
	var origin_pos = deck_container.global_position
	
	# Set card properties
	card.setFlip(true)
	card.global_position = origin_pos
	
	# Create draw animation
	var draw_position = Vector3(0, 2, 1)
	var animator = card.getAnimator()
	animator.draw_card(
		origin_pos,
		draw_position,
		dest_hand.global_position,
		0.0,
		card_data.playerControlled and card.is_facedown
	)
	
	# Reparent to destination hand
	GameUtility.reparentCardWithoutMovingRepresentation(card, dest_hand)
	
	# Wait for animation to complete
	await get_tree().create_timer(0.6).timeout
	
	# Arrange cards in hand
	dest_hand.arrange_cards_fan([card])

## Animate card entering battlefield
func animate_card_to_battlefield(card_data: CardData, dest_zone: GameZone.e) -> void:
	if headless:
		return
	
	# Get destination container
	var dest = get_zone_container(dest_zone)
	if not dest:
		push_error("GameView.animate_card_to_battlefield: Could not find battlefield container")
		return
	
	# Get or create Card view
	var card = card_data.get_card_object()
	if not card or not is_instance_valid(card):
		card = create_card_view(card_data, card_data.playerControlled, false)
	
	# Reparent to battlefield container
	GameUtility.reparentWithoutMoving(card, dest)
	
	# Get next available battlefield position
	var target_position = get_next_battlefield_location()
	if target_position == Vector3.INF:
		push_error("GameView.animate_card_to_battlefield: No space on battlefield")
		return
	
	# Set visual properties
	card.setFlip(true)
	card.getAnimator().make_small()
	
	# Animate to target position
	var local_target = target_position + Vector3(0, 0.2, 0)
	var tween = card.getAnimator().move_to_position(local_target, 0.8, dest)
	if tween:
		await tween.finished

## Animate card to graveyard
func animate_card_to_graveyard(card_data: CardData, graveyard_position: Vector3) -> void:
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		push_error("GameView.animate_card_to_graveyard: No view exists for card")
		return
	
	var tween = card.getAnimator().move_to_position(graveyard_position, 0.5)
	if tween:
		await tween.finished

## Animate card to combat zone
func animate_card_to_combat(card_data: CardData, combat_spot: CombatantFightingSpot) -> void:
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		push_error("GameView.animate_card_to_combat: No view exists for card")
		return
	
	# CombatantFightingSpot.setCard handles the animation
	combat_spot.setCard(card)

## Animate card back to base from combat
func animate_card_to_base(card_data: CardData, base_position: Vector3, parent: Node) -> void:
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		push_error("GameView.animate_card_to_base: No view exists for card")
		return
	
	var local_target = base_position + Vector3(0, 0.2, 0)
	var tween = card.getAnimator().move_to_position(local_target, 0.8, parent)
	if tween:
		await tween.finished

## Generic card movement animation
func animate_card_move(card_data: CardData, target_position: Vector3, duration: float = 0.5) -> void:
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		push_error("GameView.animate_card_move: No view exists for card")
		return
	
	card.setFlip(true)
	var tween = card.getAnimator().move_to_position(target_position, duration)
	if tween:
		await tween.finished

## Move card view to appropriate zone container (reparent in scene tree)
func move_card_view_to_zone(card_data: CardData, zone: GameZone.e) -> void:
	var card = card_data.get_card_object()
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
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		return
	
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	card.queue_free()

## Update hand arrangement
func arrange_hand(hand_zone: CardHand, cards: Array[Card] = []) -> void:
	if cards.is_empty():
		hand_zone.arrange_cards_fan()
	else:
		hand_zone.arrange_cards_fan(cards)

## Setup UI connections and bindings
func setup_ui_connections(game_data: GameData, on_draw_callback: Callable, on_admin_callback: Callable) -> void:
	# Setup UI to follow game data signals
	game_ui.setup_game_data(game_data)
	
	# Connect button press signals
	draw_button.pressed.connect(on_draw_callback)
	admin_button.pressed.connect(on_admin_callback)

## Set zone names for GameData queries
func set_zone_names() -> void:
	deck.zone_name = GameZone.e.DECK_PLAYER
	deck_opponent.zone_name = GameZone.e.DECK_OPPONENT
	extra_deck.zone_name = GameZone.e.EXTRA_DECK_PLAYER
	graveyard.zone_name = GameZone.e.GRAVEYARD_PLAYER
	graveyard_opponent.zone_name = GameZone.e.GRAVEYARD_OPPONENT

## Get next empty location on battlefield
func get_next_battlefield_location() -> Vector3:
	return player_base.getNextEmptyLocation()

## Update deck visual size
func update_deck_visuals() -> void:
	deck.update_size()
	deck_opponent.update_size()

## Get graveyard for player or opponent
func get_graveyard(is_player: bool) -> Graveyard:
	return graveyard if is_player else graveyard_opponent

## Show extra hand and hide player hand
func show_extra_hand() -> void:
	player_hand.hide()
	extra_hand.show()

## Hide extra hand and show player hand
func hide_extra_hand() -> void:
	extra_hand.hide()
	player_hand.show()

## Toggle extra deck view (handles show/hide logic)
## Returns: true if extra hand is now visible, false if hidden
func toggle_extra_deck_view() -> bool:
	if extra_hand.visible:
		hide_extra_hand()
		return false
	elif extra_deck.outline.visible:
		show_extra_hand()
		return true
	return false

## Arrange extra deck cards in hand (for display only)
func arrange_extra_deck_hand(castable_cards: Array[CardData], create_card_callback: Callable) -> void:
	if headless:
		return
	
	var spacing = 0.8  # Horizontal spacing between cards
	var loopC = 0
	
	# Clear existing cards
	for c in extra_hand.get_children():
		c.queue_free()
	
	await extra_hand.get_tree().process_frame
	
	# Create card views for castable cards
	for card_data in castable_cards:
		var card = create_card_callback.call(card_data, true)
		GameUtility.reparentCardWithoutMovingRepresentation(card, extra_hand)
		card.setFlip(true)
		
		# Position the card
		card.position.x = spacing * loopC
		card.position.y = 0
		card.position.z = 0
		card.card_representation.position = Vector3.ZERO
		
		card.getAnimator().make_small()
		
		loopC += 1
	
	arrange_hand(extra_hand)

## Animate card to casting position
func animate_casting_preparation(card: Card, is_facedown: bool) -> void:
	if headless:
		return
	
	await card.getAnimator().cast_position(is_facedown).finished

## Restore cancelled card to its original location
func restore_cancelled_card(card: Card, original_parent: Node) -> void:
	if headless:
		return
	
	card.getAnimator().make_small()
	if original_parent is CardHand:
		original_parent.arrange_card_fan(card)

## Show floating text at a position
func show_floating_text(position: Vector3, text: String, color: Color, game_node: Node) -> void:
	if headless:
		return
	
	AnimationsManagerAL.show_floating_text(game_node, position, text, color)

## Animate combat strike between two cards
func animate_combat_strike(attacker: Card, defender: Card) -> void:
	if headless:
		return
	
	attacker.getAnimator().animate_combat_strike(defender)
	defender.getAnimator().animate_combat_strike(attacker)

## Create and animate card views for drawing cards from deck
## Returns array of created Card views (empty in headless mode)
func create_and_animate_drawn_cards(cards_to_draw: Array[CardData], is_player: bool, deck_position: Vector3, create_card_callback: Callable) -> Array[Card]:
	if headless:
		return []
	
	var hand = player_hand if is_player else opponent_hand
	var _deck = deck if is_player else deck_opponent
	var card_views: Array[Card] = []
	
	# Create Card views
	for card_data in cards_to_draw:
		var card_view = create_card_callback.call(card_data, is_player, null)
		card_view.global_position = deck_position
		card_views.append(card_view)
		hand.add_child(card_view)
	
	# Update deck visual size
	_deck.update_size()
	
	# Arrange hand layout
	hand.arrange_cards_fan(card_views)
	
	# Keep all newly added cards' representations at deck position
	for card in card_views:
		card.card_representation.global_position = deck_position
	
	# Animate each card
	for i in range(card_views.size()):
		var card = card_views[i]
		animate_draw_card(
			card.cardData,
			deck_position,
			card.global_position,
			i * 0.1,
			is_player and card.is_facedown
		)
	
	# Wait for all animations to complete
	await get_tree().create_timer(card_views.size() * 0.2 + 0.6).timeout
	
	return card_views

## Update extra deck outline visibility
func update_extra_deck_outline(has_castable_cards: bool) -> void:
	if has_castable_cards:
		extra_deck.get_node("MeshInstance3D/Outline").show()
	else:
		extra_deck.get_node("MeshInstance3D/Outline").hide()

## Show admin console
func show_admin_console() -> void:
	admin_scene.show()

## Get combat zones array
func get_combat_zones() -> Array[CombatZone]:
	return combat_zones

## Get player base
func get_player_base() -> PlayerBase:
	return player_base

## Get alternative cast choice control
func get_alternative_cast_choice() -> Control:
	return alternative_cast_choice

## Get game UI
func get_game_ui() -> GameUI:
	return game_ui
