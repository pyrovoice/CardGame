extends Resource
class_name HighlightManager

## Single source of truth for all 3D Card visual highlight state.
## External systems (SelectionManager, effects)

enum CardHighlightState {
	NONE,         ## Normal, no tint, no outline
	CASTABLE,     ## Blue outline, normal brightness
	DIMMED,       ## Greyed out (non-castable during a highlight pass)
	SELECTED,     ## Green tint, green outline (chosen during selection)
	DRAG_OUTSIDE, ## Red outline (being dragged outside the hand zone)
}

var game: Game
var currently_dragged_card: Card = null
var drag_outside_hand: bool = false

## Registry of all card highlight states managed by this system.
var _highlight_states: Dictionary = {}  # Card -> CardHighlightState

func _init(_game: Game) -> void:
	game = _game

# ─── Card animator connection ────────────────────────────────────────────────

func connect_to_card_animator(card: Card) -> void:
	if not card or not card.getAnimator():
		return
	var animator = card.getAnimator()
	animator.drag_started.connect(_on_card_drag_started)
	animator.drag_position_changed.connect(_on_card_drag_position_changed)
	animator.drag_ended.connect(_on_card_drag_ended)

# ─── Public API ──────────────────────────────────────────────────────────────

func set_card_highlight(card: Card, state: CardHighlightState) -> void:
	"""Set a card's highlight state and apply visuals immediately."""
	if not is_instance_valid(card):
		return
	if state == CardHighlightState.NONE:
		_highlight_states.erase(card)
	else:
		_highlight_states[card] = state
	_apply_visual(card, state)

func clear_card_highlight(card: Card) -> void:
	"""Remove highlight from a single card (resets to NONE)."""
	set_card_highlight(card, CardHighlightState.NONE)

func clear_all() -> void:
	"""Remove all tracked highlights and reset every card to NONE visuals."""
	var cards: Array = _highlight_states.keys().duplicate()
	_highlight_states.clear()
	for card in cards:
		if is_instance_valid(card):
			_apply_visual(card, CardHighlightState.NONE)

# ─── Turn highlighting ────────────────────────────────────────────────────────

func onHighlight() -> void:
	"""Highlight castable cards in hand/extra deck; dim the rest."""
	var hand_cards = game.game_view.player_hand.get_children() if game and game.game_view.player_hand else []
	print("💡 [HIGHLIGHT] onHighlight called. Hand has ", hand_cards.size(), " cards: ", hand_cards.map(func(c): return c.name if c else 'null'))
	clear_all()
	_highlightHandCards()
	_highlightExtraDeckDisplayCards()

func _highlightHandCards() -> void:
	if not game or not game.game_view.player_hand:
		return
	for card in game.game_view.player_hand.get_children():
		if card is Card:
			var state = CardHighlightState.CASTABLE if CardPaymentManagerAL.isCardCastable(card.cardData) else CardHighlightState.DIMMED
			set_card_highlight(card, state)

func _highlightExtraDeckDisplayCards() -> void:
	if not game or not game.game_view.extra_hand:
		return
	for card in game.game_view.extra_hand.get_children():
		if card is Card:
			var state = CardHighlightState.CASTABLE if CardPaymentManagerAL.isCardCastable(card.cardData) else CardHighlightState.DIMMED
			set_card_highlight(card, state)

# ─── Drag handling ────────────────────────────────────────────────────────────

func _on_card_drag_started(card: Card) -> void:
	start_card_drag(card)

func _on_card_drag_position_changed(card: Card, is_outside_hand: bool) -> void:
	update_card_drag_position(card, is_outside_hand)

func _on_card_drag_ended(card: Card) -> void:
	end_card_drag(card)

func start_card_drag(card: Card) -> void:
	currently_dragged_card = card
	drag_outside_hand = false
	_update_drag_highlights()

func update_card_drag_position(card: Card, is_outside_hand: bool) -> void:
	if card != currently_dragged_card:
		return
	if drag_outside_hand != is_outside_hand:
		drag_outside_hand = is_outside_hand
		_update_drag_highlights()

func end_card_drag(card: Card) -> void:
	if card != currently_dragged_card:
		return
	currently_dragged_card = null
	drag_outside_hand = false
	onHighlight()

func _update_drag_highlights() -> void:
	if not currently_dragged_card:
		return
	clear_all()
	var state: CardHighlightState
	if drag_outside_hand:
		state = CardHighlightState.DRAG_OUTSIDE
	elif CardPaymentManagerAL.isCardCastable(currently_dragged_card.cardData):
		state = CardHighlightState.CASTABLE
	else:
		state = CardHighlightState.NONE
	set_card_highlight(currently_dragged_card, state)

# ─── Visual application ───────────────────────────────────────────────────────

func _apply_visual(card: Card, state: CardHighlightState) -> void:
	if not is_instance_valid(card):
		return

	# Modulate on Card2D
	if card.card_2d:
		var color: Color
		match state:
			CardHighlightState.DIMMED:       color = Color(0.6, 0.6, 0.6)
			CardHighlightState.SELECTED:     color = Color(0.7, 1.0, 0.7)
			_:                               color = Color.WHITE
		card.card_2d.set_base_modulate(color)

	# Outline mesh
	var show_outline := state in [CardHighlightState.CASTABLE, CardHighlightState.SELECTED, CardHighlightState.DRAG_OUTSIDE]
	if card.highlight_mesh:
		card.highlight_mesh.visible = show_outline
		if show_outline:
			var outline_color: Color
			match state:
				CardHighlightState.CASTABLE:     outline_color = Color.BLUE
				CardHighlightState.SELECTED:     outline_color = Color.GREEN
				CardHighlightState.DRAG_OUTSIDE: outline_color = Color.RED
				_:                               outline_color = Color.WHITE
			card.set_outline_color(outline_color)
