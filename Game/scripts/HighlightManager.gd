extends Resource
class_name HighlightManager

var game: Game
var currentlyHighlightedCards: Array[Card] = []
var currently_dragged_card: Card = null
var drag_outside_hand: bool = false

func _init(_game):
	game = _game
	# Connect to CardAnimator signals through all cards when they're created
	# This will be handled by connecting to individual card animators

func connect_to_card_animator(card: Card):
	"""Connect to a card's animator signals for drag notifications"""
	if not card or not card.getAnimator():
		return
	
	var animator = card.getAnimator()
	animator.drag_started.connect(_on_card_drag_started)
	animator.drag_position_changed.connect(_on_card_drag_position_changed) 
	animator.drag_ended.connect(_on_card_drag_ended)

func _on_card_drag_started(card: Card):
	"""Handle card drag start"""
	start_card_drag(card)

func _on_card_drag_position_changed(card: Card, is_outside_hand: bool):
	"""Handle card drag position changes"""
	update_card_drag_position(card, is_outside_hand)

func _on_card_drag_ended(card: Card):
	"""Handle card drag end"""
	end_card_drag(card)
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
	if CardPaymentManagerAL.isCardCastable(currently_dragged_card.cardData):
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
			var is_castable = CardPaymentManagerAL.isCardCastable(card.cardData)
			
			card.set_selectable(is_castable)
			if is_castable:
				currentlyHighlightedCards.append(card)

func _highlightExtraDeckDisplayCards():
	"""Toggle highlight on extra deck display cards based on castability"""
	if not game or not game.extra_hand:
		return
		
	var display_cards = game.extra_hand.get_children()
	for card: Card in display_cards:
		if card is Card:
			var is_castable = CardPaymentManagerAL.isCardCastable(card.cardData)
			card.set_selectable(is_castable)
			if is_castable:
				currentlyHighlightedCards.append(card)
