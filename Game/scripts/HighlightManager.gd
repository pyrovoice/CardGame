extends Resource
class_name HighlightManager

var game: Game
var currentlyHighlightedCards: Array[Card] = []
var currently_dragged_card: Card = null
var drag_outside_hand: bool = false

func _init(_game):
	game = _game
	# Connect to player control drag events
	if game and game.player_control:
		# Connect the cardDragPositionChanged signal to onCardDragged
		game.player_control.cardDragPositionChanged.connect(onCardDragged)

func onCardDragged(card: Card, is_outside_hand: bool, _pos):
	"""Handle card drag with highlighting - blue or red depending on hand zone"""
	currently_dragged_card = card
	drag_outside_hand = is_outside_hand
	
	# Update highlights based on drag state
	_update_drag_highlights()

func onHighlight():
	"""Highlight castable cards in hand and extra deck"""
	# Clear all previously highlighted cards first
	_clearAllHighlights()
	
	# Check cards in hand for highlighting
	_highlightHandCards()
	
	# Highlight extra deck display cards based on castability
	_highlightExtraDeckDisplayCards()

func start_card_drag(card: Card):
	"""Called when a card starts being dragged"""
	currently_dragged_card = card
	drag_outside_hand = false
	
	# Update highlights: keep blue on dragged card if castable, clear others
	_update_drag_highlights()

func update_card_drag_position(card: Card, is_outside_hand: bool):
	"""Called during card drag to update position and highlights"""
	if card != currently_dragged_card:
		return
	
	if drag_outside_hand != is_outside_hand:
		drag_outside_hand = is_outside_hand
		_update_drag_highlights()

func end_card_drag(card: Card):
	"""Called when card drag ends"""
	if card != currently_dragged_card:
		return
	
	# Reset drag state
	currently_dragged_card = null
	drag_outside_hand = false
	
	# Restore normal highlights
	onHighlight()

func _clearAllHighlights():
	"""Remove all highlights, should be called by other methods"""
	for card in currentlyHighlightedCards:
		if is_instance_valid(card):
			card.set_selectable(false)
			card.set_drag_outside_hand(false)
	currentlyHighlightedCards.clear()

func _update_drag_highlights():
	"""Update highlights during drag operations"""
	if not currently_dragged_card:
		return
	
	# Clear all highlights first
	_clearAllHighlights()
	
	# Apply appropriate highlight to dragged card
	if CardPaymentManagerAL.isCardCastable(currently_dragged_card):
		currently_dragged_card.set_selectable(true)
		currently_dragged_card.set_drag_outside_hand(drag_outside_hand)
		currentlyHighlightedCards.append(currently_dragged_card)

func _highlightHandCards():
	"""Toggle highlight on cards in hand based on castability"""
	if not game or not game.player_hand:
		return
		
	var hand_cards = game.player_hand.get_children()
	for card: Card in hand_cards:
		if card is Card:
			var is_castable = CardPaymentManagerAL.isCardCastable(card)
			card.set_selectable(is_castable)
			if is_castable:
				currentlyHighlightedCards.append(card)

func _highlightExtraDeckDisplayCards():
	"""Toggle highlight on extra deck display cards based on castability"""
	if not game or not game.extra_deck_display:
		return
		
	var display_cards = game.extra_deck_display.get_children()
	for card: Card in display_cards:
		if card is Card:
			var is_castable = CardPaymentManagerAL.isCardCastable(card)
			card.set_selectable(is_castable)
			if is_castable:
				currentlyHighlightedCards.append(card)
