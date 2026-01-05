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

static func createCardFromData(game: Game, cardData: CardData, player_controlled: bool, isToken: bool):
	if cardData == null:
		return null
	
	var CARD = preload("res://Game/scenes/Card.tscn")
	
	if !CARD.can_instantiate():
		push_error("Can't instantiate.")
		return
	
	var card_instance: Card = CARD.instantiate() as Card
	
	if card_instance == null:
		push_error("Card instance is null! Check if Card.gd is attached to Card.tscn root.")
		print("❌ [CREATE CARD DEBUG] card_instance is null after instantiate!")
		return
	
	game.add_child(card_instance)
	cardData.playerControlled = player_controlled
	cardData.playerOwned = player_controlled
	card_instance.setData(cardData)
	card_instance.name = cardData.cardName + "_" + str(Game.getObjectCountAndIncrement())
	card_instance.isToken = isToken
	game.connect_card_to_highlight_manager(card_instance)
	
	return card_instance

static func getCardZone(game: Game, card: Card) -> GameZone.e:
	"""Determine what zone a card is currently in based on its parent and controller"""
	if not card:
		return GameZone.e.UNKNOWN
		
	# Fallback to parent-based detection
	var parent = card.get_parent()
	if not parent:
		return GameZone.e.DECK # Default fallback
	
	# Check against actual game zone variables instead of hardcoded strings
	if parent == game.player_hand or parent == game.opponent_hand :
		return GameZone.e.HAND
	elif parent == game.player_base:
		return GameZone.e.PLAYER_BASE
	elif parent == game.graveyard or parent == game.graveyard_opponent:
		return GameZone.e.GRAVEYARD
	elif parent == game.deck or parent == game.deck_opponent:
		return GameZone.e.DECK
	elif parent == game.extra_hand:
		return GameZone.e.EXTRA_DECK
	else:
		# Check if parent is a combat zone spot
		for combat_zone in game.combatZones:
			if parent in combat_zone.allySpots or parent in combat_zone.ennemySpots:
				return GameZone.e.COMBAT_ZONE
		
		# Check if parent is a CombatantFightingSpot (fallback)
		if parent is CombatantFightingSpot:
			return GameZone.e.COMBAT_ZONE
		
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
	if valid_card_filter == "Any":
		return true
	
	# Use the universal filtering method from CardPaymentManager
	var cards_to_filter = [card]
	var filtered_cards = CardPaymentManagerAL.filterCardsByParameters(cards_to_filter, valid_card_filter, CardPaymentManagerAL.current_game)
	return filtered_cards.size() > 0

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

static func reparentWithoutMoving(object: Node3D, newParent: Node3D):
	var globalPosBefore = object.global_position
	if object.get_parent():
		object.reparent(newParent)
	else:
		newParent.add_child(object)
	object.global_position = globalPosBefore
	
static func reparentCardWithoutMovingRepresentation(card: Card, newParent, cardNewPosition: Vector3 = Vector3.INF):
	var globalPosBefore = card.card_representation.global_position
	if cardNewPosition == null || cardNewPosition == Vector3.INF:
		cardNewPosition = card.position
	if card.get_parent():
		card.reparent(newParent)
	else:
		newParent.add_child(card)
	card.position = cardNewPosition
	card.card_representation.global_position = globalPosBefore

## Filter cards by complex criteria with AND (+) and OR (/) logic
## Example: "Card.YouCtrl+Creature+Cost.1" matches your 1-cost creatures
## Example: "Creature/Spell" matches creatures OR spells
static func filterCardsByParameters(cards: Array[Card], filter: String, game: Game) -> Array[Card]:
	"""Filter cards by complex criteria using AND (+) and OR (/) logic"""
	if filter == "Any":
		return cards
	
	var matching_cards: Array[Card] = []
	
	# Handle OR logic first - split by '/'
	var or_parts = filter.split("/")
	
	for card in cards:
		var matches_any_or_part = false
		for or_part in or_parts:
			# For each OR part, parse criteria and check if card matches
			var criteria = parseCriteria(or_part)
			if matchesAllCriteria(card, criteria, game):
				matches_any_or_part = true
				break
		
		if matches_any_or_part:
			matching_cards.append(card)
	
	return matching_cards

static func parseCriteria(filter_str: String) -> Dictionary:
	"""Parse a filter string with AND logic (+) into structured criteria"""
	var criteria = {
		"controller": "",  # "YouCtrl", "OppCtrl", or ""
		"card_types": [],  # Array of card types: ["Creature", "Spell", etc.]
		"subtypes": [],    # Array of subtypes: ["Goblin", "Human", etc.]
		"cost": -1,        # Exact cost, -1 = any
		"cost_min": -1,    # Minimum cost, -1 = no min
		"cost_max": -1,    # Maximum cost, -1 = no max
		"power": -1,       # Exact power, -1 = any
		"power_min": -1,   # Minimum power, -1 = no min
		"power_max": -1,   # Maximum power, -1 = no max
		"token": ""        # "Token", "NonToken", or ""
	}
	
	# Split by '+' for AND logic
	var parts = filter_str.split("+")
	for part in parts:
		process_filter_part(part, criteria)
	
	return criteria

static func process_filter_part(part: String, criteria: Dictionary) -> void:
	"""Process a single filter part and update criteria dictionary"""
	if part == "Card.YouCtrl":
		criteria.controller = "YouCtrl"
	elif part == "Card.OppCtrl":
		criteria.controller = "OppCtrl"
	elif part == "YouCtrl":
		criteria.controller = "YouCtrl"
	elif part == "OppCtrl":
		criteria.controller = "OppCtrl"
	elif part == "Token":
		criteria.token = "Token"
	elif part == "NonToken":
		criteria.token = "NonToken"
	elif part.begins_with("Cost."):
		criteria.cost = int(part.substr(5))
	elif part.begins_with("MinCost."):
		criteria.cost_min = int(part.substr(8))
	elif part.begins_with("MaxCost."):
		criteria.cost_max = int(part.substr(8))
	elif part.begins_with("Power."):
		criteria.power = int(part.substr(6))
	elif part.begins_with("MinPower."):
		criteria.power_min = int(part.substr(9))
	elif part.begins_with("MaxPower."):
		criteria.power_max = int(part.substr(9))
	elif part in ["Creature", "Spell", "Land", "Artifact", "Enchantment"]:
		criteria.card_types.append(part)
	else:
		# Treat as subtype (Goblin, Grown-up, etc.)
		criteria.subtypes.append(part)

static func matchesAllCriteria(card: Card, criteria: Dictionary, game: Game) -> bool:
	"""Check if a card matches all the parsed criteria"""
	var card_data = card.cardData
	
	# Check controller
	if criteria.controller == "YouCtrl" and not card_data.playerControlled:
		return false
	elif criteria.controller == "OppCtrl" and card_data.playerControlled:
		return false
	
	# Check token status
	if criteria.token == "Token" and not card.isToken:
		return false
	elif criteria.token == "NonToken" and card.isToken:
		return false
	
	# Check card types
	if not criteria.card_types.is_empty():
		var has_required_type = false
		for required_type in criteria.card_types:
			# Use centralized conversion method
			if CardData.isValidCardTypeString(required_type):
				var card_type = CardData.stringToCardType(required_type)
				if card_data.hasType(card_type):
					has_required_type = true
					break
		if not has_required_type:
			return false
	
	# Check subtypes
	if not criteria.subtypes.is_empty():
		var has_required_subtype = false
		for required_subtype in criteria.subtypes:
			if required_subtype in card_data.subtypes:
				has_required_subtype = true
				break
		if not has_required_subtype:
			return false
	
	# Check exact cost
	if criteria.cost >= 0 and card_data.goldCost != criteria.cost:
		return false
	
	# Check cost range
	if criteria.cost_min >= 0 and card_data.goldCost < criteria.cost_min:
		return false
	if criteria.cost_max >= 0 and card_data.goldCost > criteria.cost_max:
		return false
	
	# Check exact power
	if criteria.power >= 0 and card_data.power != criteria.power:
		return false
	
	# Check power range
	if criteria.power_min >= 0 and card_data.power < criteria.power_min:
		return false
	if criteria.power_max >= 0 and card_data.power > criteria.power_max:
		return false
	
	return true
