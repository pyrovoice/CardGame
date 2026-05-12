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
@onready var player_hand: CardHand = $PlayerHand
@onready var extra_hand: CardHand = $ExtraHand
@onready var opponent_hand: CardHand = $OpponentHand
@onready var player_base: PlayerBase = $playerBase
@onready var deck: Deck = $Deck
@onready var deck_opponent: Deck = $DeckOpponent
@onready var extra_deck: CardContainer = $extraDeck
@onready var graveyard: Graveyard = $graveyard
@onready var graveyard_opponent: Graveyard = $graveyardOpponent
var combat_zones: Array[CombatZone] = []
@onready var opponentbase: PlayerBase = $opponentbase
@onready var recycle_area: Area3D = $recycleArea

# UI references
@onready var game_ui: GameUI = $UI
@onready var admin_button: Button = $UI/AdminButton
@onready var alternative_cast_choice: Control = $UI/AlternativeCastChoice
@onready var admin_scene: AdminConsole = $UI/AdminScene
@onready var container_visualizer: CardContainerVizualizer = $UI/CardContainerVizualizer
@onready var main_action_button: Button = $UI/mainActionButton
@onready var secondary_action_button: Button = $UI/secondaryActionButton

# Headless mode - skips all animations and visual updates
var headless: bool = false

const CARD_SCENE = preload("res://Game/scenes/Card.tscn")

# Container visualizer instance (created on demand)
var current_viewing_container: CardContainer = null

func _init():
	pass

## Initialize view by finding all child nodes from itself
func setup(is_headless: bool = false) -> void:
	headless = is_headless
	# Combat zones
	combat_zones = [
		get_node("combatZone"),
		get_node("combatZone2"),
		get_node("combatZone3")
	]

## Create a Card view node for the given CardData
func create_card_view(card_data: CardData, zone: GameZone.e = GameZone.e.UNKNOWN) -> Card:
	if headless:
		return card_data.get_card_object() if card_data else null
	
	# Container zones (deck, graveyard) don't need Card 3D nodes - only 2D visualizer
	if _is_container_zone(zone):
		return null

	var card: Card = CARD_SCENE.instantiate()
	if not card:
		push_error("GameView.create_card_view: Failed to instantiate Card scene")
		return null

	if card_data:
		card.setData(card_data)
		card.name = card_data.cardName + "_" + str(Game.getObjectCountAndIncrement())

	var game = get_parent() as Game

	if zone != GameZone.e.UNKNOWN:
		var zone_container = get_zone_container(zone)
		if zone_container:
			zone_container.add_child(card)
			
			# Arrange hand when adding cards to hand zones (for non-draw effects like CreateCard)
			if zone == GameZone.e.HAND_PLAYER or zone == GameZone.e.HAND_OPPONENT:
				# Cards in player hand should be face-up
				if zone == GameZone.e.HAND_PLAYER and card_data:
					card_data.is_facedown = false
					card.updateDisplay()
				if zone_container is CardHand:
					zone_container.arrange_cards_fan(([card] as Array[Card]))
		else:
			game.add_child(card)
		
		# Set card size based on zone: cards in hand are big, everywhere else is small
		if zone != GameZone.e.HAND_PLAYER and zone != GameZone.e.HAND_OPPONENT:
			card.getAnimator().make_small()
	
	# Connect to highlight manager AFTER card is in tree so @onready variables are initialized
	if game:
		game.connect_card_to_highlight_manager(card)

	return card

func _is_container_zone(zone: GameZone.e) -> bool:
	return zone == GameZone.e.DECK_PLAYER or \
		zone == GameZone.e.DECK_OPPONENT or \
		zone == GameZone.e.GRAVEYARD_PLAYER or \
		zone == GameZone.e.GRAVEYARD_OPPONENT or \
		zone == GameZone.e.EXTRA_DECK_PLAYER

func get_target_node_for_zone(zone: GameZone.e) -> Node3D:
	var zone_container = get_zone_container(zone)
	if zone_container and zone_container is Node3D:
		return zone_container as Node3D
	return null

func _get_or_create_card_for_zone_move(card_data: CardData) -> Card:
	var card = card_data.get_card_object() if card_data else null
	if card and is_instance_valid(card):
		return card

	if not card_data:
		push_error("GameView._get_or_create_card_for_zone_move: card_data is null")
		return null

	# No existing card view - create a temporary one for animation.
	# (Card was in a container zone like graveyard/deck, so no persistent view existed.)
	card = CARD_SCENE.instantiate()
	if card:
		card.setData(card_data)
		card.name = card_data.cardName + "_temp_" + str(Game.getObjectCountAndIncrement())
		add_child(card)
	return card

func move_card_to_zone(card_data: CardData, target_zone: GameZone.e, duration: float = 0.5, local_target_offset: Vector3 = Vector3.INF, turn_face_up: bool = true, make_small_before_move: bool = false) -> void:
	if headless:
		return

	var card = _get_or_create_card_for_zone_move(card_data)
	if not card:
		push_error("GameView.move_card_to_zone: Could not get or create card view")
		return

	var target_node = get_target_node_for_zone(target_zone)
	if not target_node:
		push_error("GameView.move_card_to_zone: Could not resolve target node for zone " + str(GameZone.e.keys()[target_zone]))
		return

	var final_local_target = local_target_offset
	if final_local_target == Vector3.INF:
		if target_zone == GameZone.e.BATTLEFIELD_PLAYER or target_zone == GameZone.e.BATTLEFIELD_OPPONENT:
			var base = player_base if target_zone == GameZone.e.BATTLEFIELD_PLAYER else opponentbase

			if turn_face_up:
				card.setFlip(true)
			if make_small_before_move:
				card.getAnimator().make_small()

			var visual_start = card.card_representation.global_position
			base.set_card(card)
			card.card_representation.global_position = visual_start

			var tween = card.getAnimator().go_to_rest(duration)
			if tween:
				await tween.finished
			return
		else:
			final_local_target = Vector3.ZERO

	if turn_face_up:
		card.setFlip(true)

	if make_small_before_move:
		card.getAnimator().make_small()

	var tween = card.getAnimator().move_to_position(final_local_target, duration, target_node)
	if tween:
		await tween.finished
	
	# If moving to a container zone, destroy the temporary Card 3D object after animation
	if _is_container_zone(target_zone) and is_instance_valid(card):
		print("📦 [VIEW] Destroying temporary Card 3D after animation to container zone: ", GameZone.e.keys()[target_zone])
		card.queue_free()

func get_zone_container(zone: GameZone.e) -> Node:
	match zone:
		GameZone.e.HAND_PLAYER:
			return player_hand
		GameZone.e.HAND_OPPONENT:
			return opponent_hand
		GameZone.e.BATTLEFIELD_PLAYER:
			return player_base
		GameZone.e.BATTLEFIELD_OPPONENT:
			return opponentbase
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
		GameZone.e.COMBAT_PLAYER_1, GameZone.e.COMBAT_OPPONENT_1:
			return combat_zones[0] if combat_zones.size() > 0 else null
		GameZone.e.COMBAT_PLAYER_2, GameZone.e.COMBAT_OPPONENT_2:
			return combat_zones[1] if combat_zones.size() > 1 else null
		GameZone.e.COMBAT_PLAYER_3, GameZone.e.COMBAT_OPPONENT_3:
			return combat_zones[2] if combat_zones.size() > 2 else null
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
	
	var tween = animator.draw_card(
		deck_position,
		draw_position,
		hand_position,
		delay,
		should_flip
	)
	
	if tween:
		await tween.finished

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
	var tween = animator.draw_card(
		origin_pos,
		draw_position,
		dest_hand.global_position,
		0.0,
		card_data.playerControlled and card_data.is_facedown
	)
	
	# Reparent to destination hand
	GameUtility.reparentCardWithoutMovingRepresentation(card, dest_hand)
	
	# Wait for animation to complete
	if tween:
		await tween.finished
	
	# Arrange cards in hand
	dest_hand.arrange_cards_fan([card])

## Animate card entering battlefield
func animate_card_to_battlefield(card_data: CardData, dest_zone: GameZone.e) -> void:
	await move_card_to_zone(card_data, dest_zone, 0.8, Vector3.INF, true, true)

## Animate card to graveyard
func animate_card_to_graveyard(card_data: CardData, graveyard_zone: GameZone.e) -> void:
	await move_card_to_zone(card_data, graveyard_zone, 0.5)

## Animate card to combat zone
func animate_card_to_combat(card_data: CardData, combat_spot: GameZone.e, targetPosition: int = -1) -> void:
	if headless:
		return
	
	var card = card_data.get_card_object()
	if not card:
		push_error("GameView.animate_card_to_combat: No view exists for card")
		return

	var combat_zone = get_zone_container(combat_spot) as CombatZone
	if not combat_zone:
		push_error("GameView.animate_card_to_combat: Invalid combat spot zone " + str(GameZone.e.keys()[combat_spot]))
		return

	# Get target container based on player team
	var ally_team: bool = card_data.playerControlled
	var target_container = combat_zone.ally_side if ally_team else combat_zone.opponent_side
	
	# Save visual position before reparenting
	var visual_start = card.card_representation.global_position
	
	# Reparent to correct slot (reorganize sets card.position = slot)
	combat_zone.set_card(card, targetPosition)
	
	# Restore visual position (reorganize's go_to_rest may have partially moved it)
	card.card_representation.global_position = visual_start
	
	# Animate representation to slot with a visible duration
	var tween = card.getAnimator().go_to_rest()
	if tween:
		await tween.finished

## Animate card back to base from combat
func animate_card_to_base(card_data: CardData, targetZone: GameZone.e) -> void:
	await move_card_to_zone(card_data, targetZone, 0.8, Vector3.INF, true, true)

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

## Recycle a card view (visual feedback for recycling)
func recycle_card_view(card_data: CardData) -> void:
	"""Handle visual feedback for card recycling
	
	Args:
		card_data: The card being recycled
	"""
	if headless:
		return
	
	print("♻️ Recycled: ", card_data.cardName)
	# TODO: Add recycling animation here (card flies to recycle area, particle effects, etc.)
	# For now, just destroy the view
	destroy_card_view(card_data)

## Update hand arrangement
func arrange_hand(hand_zone: CardHand, cards: Array[Card] = []) -> void:
	if cards.is_empty():
		hand_zone.arrange_cards_fan()
	else:
		hand_zone.arrange_cards_fan(cards)

## Setup UI connections and bindings
func setup_ui_connections(game_data: GameData, on_main_action_callback: Callable, on_secondary_action_callback: Callable, on_admin_callback: Callable) -> void:
	# Setup UI to follow game data signals
	game_ui.setup_game_data(game_data)
	
	# Connect button press signals
	main_action_button.pressed.connect(on_main_action_callback)
	secondary_action_button.pressed.connect(on_secondary_action_callback)
	admin_button.pressed.connect(on_admin_callback)

## Set zone names for GameData queries
func set_zone_names() -> void:
	deck.zone_name = GameZone.e.DECK_PLAYER
	deck_opponent.zone_name = GameZone.e.DECK_OPPONENT
	extra_deck.zone_name = GameZone.e.EXTRA_DECK_PLAYER
	graveyard.zone_name = GameZone.e.GRAVEYARD_PLAYER
	graveyard_opponent.zone_name = GameZone.e.GRAVEYARD_OPPONENT

## Get next empty location on battlefield
func get_next_battlefield_location(is_player: bool = true) -> Vector3:
	return player_base.getNextEmptyLocation() if is_player else opponentbase.getNextEmptyLocation()

## Update deck visual size
func update_deck_visuals() -> void:
	deck.update_size()
	deck_opponent.update_size()

## Get graveyard for player or opponent
func get_graveyard(is_player: bool) -> Graveyard:
	return graveyard if is_player else graveyard_opponent

## Show extra hand and hide player hand
const HAND_OFFSCREEN_Y := -1000.0
const HAND_DEFAULT_POSITION := Vector3(-0.072, 1.721, 2.165)

func show_extra_hand() -> void:
	player_hand.position.y = HAND_OFFSCREEN_Y
	extra_hand.position = HAND_DEFAULT_POSITION
	player_hand.hide()
	extra_hand.show()

## Hide extra hand and show player hand
func hide_extra_hand() -> void:
	extra_hand.position.y = HAND_OFFSCREEN_Y
	player_hand.position = HAND_DEFAULT_POSITION
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
func arrange_extra_deck_hand(castable_cards: Array[CardData]) -> void:
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
		var card = create_card_view(card_data, GameZone.e.UNKNOWN)
		extra_hand.add_child(card)
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
func create_and_animate_drawn_cards(cards_to_draw: Array[CardData], is_player: bool) -> Array[Card]:
	if headless:
		return []
	
	var hand = player_hand if is_player else opponent_hand
	var _deck = deck if is_player else deck_opponent
	var deck_position = _deck.global_position
	var card_views: Array[Card] = []
	
	# Create Card views without adding to hand yet - zone UNKNOWN skips parenting and arrangement
	for card_data in cards_to_draw:
		var card_view = create_card_view(card_data, GameZone.e.UNKNOWN)
		add_child(card_view)
		card_view.global_position = deck_position
		card_views.append(card_view)
	
	# Arrange into hand: reparents cards to hand at correct fan positions,
	# preserves card_representation at deck_position (via setPositionWithoutMovingRepresentation)
	hand.arrange_cards_fan(card_views)
	
	# Record the final world positions (hand.global + fan offset per card)
	var final_positions: Array[Vector3] = []
	for card in card_views:
		final_positions.append(card.global_position)
	
	# Update deck visual size
	_deck.update_size()
	
	# Animate each card — draw_card sets card_representation.global_position = from_pos itself,
	# then tweens to final_position. go_to_rest() (priority 0) is killed by draw_card (priority 1).
	var draw_position_base = Vector3(0, 2, 1)
	var last_tween: Tween = null
	for i in range(card_views.size()):
		var card_view = card_views[i]
		var offset_x = (i - (card_views.size() - 1) / 2.0) * 0.6
		var draw_position = draw_position_base + Vector3(offset_x, 0, 0)
		
		var tween = card_view.getAnimator().draw_card(
			deck_position,
			draw_position,
			final_positions[i],
			i * 0.1,
			is_player and card_view.cardData.is_facedown
		)
		if tween:
			last_tween = tween
	
	# Wait for the last card's tween to finish (it has the longest stagger delay)
	if last_tween:
		await last_tween.finished
	
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

# --- Battlefield focus ---
const _WIDE_POSITIONS: Array = [
	Vector3(-6.8445325, -0.001, 0.0),
	Vector3(-0.112, -0.001, 0.5769086),
	Vector3(6.4710474, -0.001, 0.0),
]
const _WIDE_SCALES: Array = [
	Vector3(1.0, 1.0, 1.0),
	Vector3(1.95, 1.95, 1.95),
	Vector3(1.0, 1.0, 1.0),
]
const _FOCUSED_POSITION := Vector3(-0.112, -0.001, 0.5769086)
const _FOCUSED_SCALE := Vector3(1.95, 1.95, 1.95)
const _MINI_POSITIONS: Array = [
	Vector3(-4.5, -0.001, 0.0),
	Vector3(4.5, -0.001, 0.0),
]
const _MINI_SCALE := Vector3(1.0, 1.0, 1.0)
const _FOCUS_TWEEN_DURATION := 0.35

func set_battlefield_focus(index: int) -> void:
	"""Move combat zones to focused or wide layout.
	index: 0-2 = focus that zone; -1 = wide view showing all three.
	"""
	if combat_zones.is_empty():
		return

	var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	if index == -1:
		# Wide view: restore all zones to original layout
		for i in range(combat_zones.size()):
			tween.tween_property(combat_zones[i], "position", _WIDE_POSITIONS[i], _FOCUS_TWEEN_DURATION)
			tween.tween_property(combat_zones[i], "scale", _WIDE_SCALES[i], _FOCUS_TWEEN_DURATION)
	else:
		# Focus one zone; place the other two as minis on the sides
		var mini_slot := 0
		for i in range(combat_zones.size()):
			if i == index:
				tween.tween_property(combat_zones[i], "position", _FOCUSED_POSITION, _FOCUS_TWEEN_DURATION)
				tween.tween_property(combat_zones[i], "scale", _FOCUSED_SCALE, _FOCUS_TWEEN_DURATION)
			else:
				tween.tween_property(combat_zones[i], "position", _MINI_POSITIONS[mini_slot], _FOCUS_TWEEN_DURATION)
				tween.tween_property(combat_zones[i], "scale", _MINI_SCALE, _FOCUS_TWEEN_DURATION)
				mini_slot += 1

## Get player base
func get_player_base() -> PlayerBase:
	return player_base

## Get alternative cast choice control
func get_alternative_cast_choice() -> Control:
	return alternative_cast_choice

## Get game UI
func get_game_ui() -> GameUI:
	return game_ui

## Show container visualizer for a CardContainer
func show_container_visualizer(container: CardContainer) -> void:
	if headless or not container:
		return
	
	# Get game instance to access GameData
	var game = get_parent() as Game
	if not game:
		push_error("GameView.show_container_visualizer: Could not get Game instance")
		return
	
	# Hide any card popup that's currently showing
	if game.player_control and game.player_control.card_popup_manager:
		game.player_control.card_popup_manager.hide_popup()
	
	# Get cards from GameData for this container's zone
	var cards_in_zone = game.game_data.get_cards_in_zone(container.zone_name)
	
	# Setup the visualizer with the card list
	container_visualizer.setContainer(cards_in_zone)
	container_visualizer.show()
	current_viewing_container = container

## Hide container visualizer
func hide_container_visualizer() -> void:
	if container_visualizer and is_instance_valid(container_visualizer):
		container_visualizer.hide()
	current_viewing_container = null

## Check if container visualizer is currently showing
func is_container_visualizer_showing() -> bool:
	return container_visualizer != null and container_visualizer.visible
