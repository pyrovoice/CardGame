extends RefCounted
class_name OpponentAI

# Reference to the main game instance
var game: Game

func _init(game_instance: Game):
	game = game_instance

func execute_main_phase():
	"""Opponent's main phase: each Lieutenant independently spends its own budget casting cards from its own hand"""
	if not game.game_data:
		return
	
	for lieutenant in game.game_data.lieutenant_datas:
		await _execute_lieutenant_main_phase(lieutenant)
	
	print("=== All Lieutenants finished their main phase ===")

func _execute_lieutenant_main_phase(lieutenant: LieutenantData):
	"""Spend a single Lieutenant's turn budget (its own gold pool, refilled to the danger level at turn start) casting cards from its own hand"""
	print("💰 ", lieutenant.role, " budget: ", lieutenant.gold.getValue())
	
	var cards_cast = 0
	var loopCount = 20
	var hand_cards = _get_lieutenant_hand_cards(lieutenant)
	while lieutenant.gold.getValue() > 0 and hand_cards.size() > 0 and loopCount > 0:
		loopCount -= 1
		# Find castable cards within budget
		var castable_cards = _get_castable_cards(hand_cards)
		
		if castable_cards.is_empty():
			print("🚫 ", lieutenant.role, ": no more castable cards within budget (", lieutenant.gold.getValue(), ")")
			break
		
		# Choose a random castable card
		var card_to_cast = castable_cards[randi() % castable_cards.size()]
		
		var dest_zone: GameZone.e = GameZone.e.UNKNOWN
		if card_to_cast.cardData.hasType(CardData.CardType.CREATURE):
			var target_location = _get_lieutenant_combat_zone(lieutenant)
			if target_location == null:
				print("🚫 No available target location for ", card_to_cast.cardData.cardName)
				hand_cards.erase(card_to_cast)
				continue
			var zone_index = game.game_view.get_combat_zones().find(target_location)
			dest_zone = (GameZone.e.COMBAT_OPPONENT_1 + zone_index) as GameZone.e
		
		await game.tryPlayCard(card_to_cast.cardData, dest_zone)
		
		# Update the hand cards list
		hand_cards = _get_lieutenant_hand_cards(lieutenant)
		cards_cast += 1
	
	print("=== ", lieutenant.role, " cast ", cards_cast, " cards ===")

func _get_lieutenant_hand_cards(lieutenant: LieutenantData) -> Array:
	"""Get all cards in this Lieutenant's own hand"""
	var hand_cards: Array = []
	var hand = game.game_view.get_zone_container(lieutenant.hand_zone)
	if not hand:
		return hand_cards
	for card_node in hand.get_children():
		if card_node is Card and card_node.cardData:
			hand_cards.append(card_node)
	return hand_cards

func _get_castable_cards(hand_cards: Array) -> Array[Card]:
	"""Get all cards from a Lieutenant's hand that can be cast within its remaining gold pool"""
	var castable: Array[Card] = []
	
	for card_node in hand_cards:
		if card_node is Card:
			var card: Card = card_node as Card
			if card.cardData and game.game_data.has_gold(card.cardData.goldCost, card.cardData):
				# TODO: Add more complex castability checks (additional costs, etc.)
				castable.append(card)
	
	return castable

func _get_lieutenant_combat_zone(lieutenant: LieutenantData) -> CombatZone:
	"""Map a Lieutenant's role to its assigned combat zone: aggro=left, control=middle, combo=right"""
	var combat_zones = game.game_view.get_combat_zones()
	var index: int
	match lieutenant.role:
		"aggro": index = 0
		"control": index = 1
		"combo": index = 2
		_: return null
	
	if combat_zones.is_empty() or index >= combat_zones.size():
		return null
	
	return combat_zones[index]
