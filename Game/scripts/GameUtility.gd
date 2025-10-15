extends RefCounted
class_name GameUtility

## Utility class containing helper methods for Game operations
## This class is designed to be used with a Game instance passed as parameter

static func _getTargetZone(target_location: Node3D) -> GameZone.e:
	"""Determine the game zone for the target location"""
	if target_location is CombatantFightingSpot:
		return GameZone.e.COMBAT_ZONE
	elif target_location is PlayerBase:
		return GameZone.e.PLAYER_BASE
	else:
		# Default to player base for unknown locations
		return GameZone.e.PLAYER_BASE

static func getAllCardsInPlay(game: Game) -> Array[Card]:
	var cards: Array[Card] = game.player_base.getCards()
	for cz: CombatZone in game.combatZones:
		cz.allySpots.filter(func(c: CombatantFightingSpot): return c.getCard() != null).map(func(c: CombatantFightingSpot): cards.push_back(c.getCard()))
		cz.ennemySpots.filter(func(c: CombatantFightingSpot): return c.getCard() != null).map(func(c: CombatantFightingSpot): cards.push_back(c.getCard()))
	return cards

static func createCardFromData(game: Game, cardData: CardData, card_type: CardData.CardType = CardData.CardType.CREATURE, player_controlled: bool = true, player_owned: bool = true):
	if cardData == null:
		push_warning("Tried to draw from empty deck.")
		return null
	
	var CARD = preload("res://Game/scenes/Card.tscn")
	if !CARD.can_instantiate():
		push_error("Can't instantiate.")
		return
	var card_instance: Card = CARD.instantiate() as Card
	if card_instance == null:
		push_error("Card instance is null! Check if Card.gd is attached to Card.tscn root.")
		return
	game.add_child(card_instance)
	card_instance.setData(cardData)
	card_instance.name = cardData.cardName + "_" + str(Game.getObjectCountAndIncrement())
	
	# Set the card type for tracking purposes
	match card_type:
		CardData.CardType.TOKEN:
			card_instance.isToken = true
		_:
			card_instance.isToken = false
	
	return card_instance

static func createToken(game: Game, cardData: CardData) -> Card:
	"""Create a token card and execute its enters-the-battlefield effects"""
	if cardData == null:
		push_warning("Tried to create token with null cardData.")
		return null
	
	# Create the card instance as a token
	var token_card = createCardFromData(game, cardData, CardData.CardType.TOKEN)
	if not token_card:
		return null
	
	# Execute the card enters logic for the token
	await game.executeCardEnters(token_card, GameZone.e.UNKNOWN, GameZone.e.PLAYER_BASE)
	
	return token_card

static func getCardZone(game: Game, card: Card) -> GameZone.e:
	"""Determine what zone a card is currently in based on its parent and controller"""
	if not card:
		return GameZone.e.UNKNOWN
		
	# Fallback to parent-based detection
	var parent = card.get_parent()
	if not parent:
		return GameZone.e.DECK # Default fallback
	
	var parent_name = parent.name
	
	# Check parent name/type to determine zone, considering both player and opponent zones
	if parent_name == "PlayerHand" or parent_name == "opponentHand":
		return GameZone.e.HAND
	elif parent_name == "playerBase" or (parent.get_script() != null and parent.get_script().get_global_name() == "PlayerBase"):
		return GameZone.e.PLAYER_BASE
	elif parent_name.begins_with("combatZone") or (parent.get_script() != null and parent.get_script().get_global_name() == "CombatantFightingSpot"):
		return GameZone.e.COMBAT_ZONE
	elif parent_name == "graveyard" or parent_name == "graveyardOpponent" or (parent.get_script() != null and parent.get_script().get_global_name() == "Graveyard"):
		return GameZone.e.GRAVEYARD
	elif parent_name == "Deck" or parent_name == "DeckOpponent" or (parent.get_script() != null and parent.get_script().get_global_name() == "Deck"):
		return GameZone.e.DECK
	elif parent_name == "extraDeck" or parent_name == "extra_deck_display" or (parent.get_script() != null and parent.get_script().get_global_name() == "CardContainer"):
		return GameZone.e.EXTRA_DECK
		
	# Default fallback
	return GameZone.e.UNKNOWN

static func get_graveyard_for_controller(game: Game, is_player_controlled: bool) -> Graveyard:
	"""Get the appropriate graveyard for a card based on its controller"""
	if is_player_controlled:
		return game.graveyard
	else:
		return game.graveyard_opponent

static func get_cards_in_graveyard(game: Game, is_player_controlled: bool) -> Array[CardData]:
	"""Get all cards in the graveyard for the specified controller"""
	var graveyard_container = game.graveyard if is_player_controlled else game.graveyard_opponent
	return graveyard_container.get_cards() if graveyard_container else []

static func _calculate_game_popup_position(game: Game) -> Vector2:
	"""Calculate the position for card popup in game view (left side of screen)"""
	var viewport_size = game.get_viewport().get_visible_rect().size
	# Use the actual enlarged viewport height for positioning
	var ENLARGED_CARD_HEIGHT = 600  # Same constant as in PlayerControl
	var POPUP_LEFT_MARGIN = 5       # Same constant as in PlayerControl
	var vertical_center = (viewport_size.y - ENLARGED_CARD_HEIGHT) / 2
	return Vector2(POPUP_LEFT_MARGIN, vertical_center)

static func _card_matches_requirement(card: Card, requirement: Dictionary) -> bool:
	var valid_card_filter = requirement.get("valid_card", "Any")
	var player_selection_script = load("res://Game/scripts/PlayerSelection.gd")
	return player_selection_script.card_matches_filter(card, valid_card_filter)

static func _requiresPlayerSelection(additional_costs: Array[Dictionary]) -> bool:
	"""Check if any additional costs require player selection (like sacrifice)"""
	for cost_data in additional_costs:
		var cost_type = cost_data.get("cost_type", "")
		if cost_type == "SacrificePermanent":
			return true  # Sacrifice always requires player selection
		# Add other cost types that require selection here
	return false

static func getControllerCards(game: Game, playerSide = true) -> Array[Card]:
	"""Get all cards the player currently controls (in play)"""
	var controlled_cards: Array[Card] = []
	
	# Add cards from player base
	var base_cards = game.player_base.getCards()
	controlled_cards.append_array(base_cards)
	
	# Add cards from combat zones (ally side only)
	for combat_zone in game.combatZones:
		for spot in combat_zone.allySpots if playerSide else combat_zone.ennemySpots:
			var card = spot.getCard()
			if card != null:
				controlled_cards.append(card)
	
	return controlled_cards

# Helper methods used by the main utility functions
static func getCardsInHand(game: Game, player_controlled: bool = true) -> Array[Card]:
	"""Get cards in hand for the specified controller"""
	var hand_container = game.player_hand if player_controlled else game.opponent_hand
	var cards: Array[Card] = []
	for child in hand_container.get_children():
		if child is Card:
			cards.append(child)
	return cards

static func getCardsInDeck(game: Game, player_controlled: bool = true) -> Array[CardData]:
	"""Get cards in deck for the specified controller"""
	var deck_container = game.deck if player_controlled else game.deck_opponent
	return deck_container.get_cards()

static func getCardsInGraveyard(game: Game, player_controlled: bool = true) -> Array[CardData]:
	"""Get cards in graveyard for the specified controller"""
	var graveyard_container = game.graveyard if player_controlled else game.graveyard_opponent
	return graveyard_container.get_cards() if graveyard_container else []
