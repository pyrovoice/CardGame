extends RefCounted
class_name OpponentAI

# Reference to the main game instance
var game: Game
var opponent_budget: int = 0

func _init(game_instance: Game):
	game = game_instance

func execute_main_phase():
	"""Opponent's main phase: draw cards, set budget, and cast cards with AI logic"""
	if not game.game_data:
		return
	# Step 2: Set budget equal to current danger level
	print("💰 Opponent budget: ", game.game_data.opponent_gold)
	
	# Step 3: Cast cards from hand while possible
	var cards_cast = 0
	var loopCount = 20
	while game.game_data.opponent_gold.getValue() > 0 and game.opponent_hand.get_children().size() > 0 and loopCount>0:
		var opponent_hand_cards = game.opponent_hand.get_children()
		loopCount -=1
		# Find castable cards within budget
		var castable_cards = _get_castable_cards(opponent_hand_cards, game.game_data.opponent_gold.getValue())
		
		if castable_cards.is_empty():
			print("🚫 No more castable cards within budget (", game.game_data.opponent_gold.getValue(), ")")
			break
		
		# Choose a random castable card
		var card_to_cast = castable_cards[randi() % castable_cards.size()]		
		# Find a target location for the card
		var target_location = _find_target_location(card_to_cast)
		
		if target_location == null:
			print("🚫 No available target location for ", card_to_cast.cardData.cardName)
			# Remove this card from consideration and continue
			opponent_hand_cards.erase(card_to_cast)
			continue
		
		# Cast the card using the existing game logic
		await game.tryPlayCard(card_to_cast, target_location)
		
		# Update the hand cards list
		opponent_hand_cards = game.opponent_hand.get_children()
		cards_cast += 1
	
	print("=== Opponent cast ", cards_cast, " cards. End of main phase ===")


func _get_castable_cards(hand_cards: Array, budget: int) -> Array[Card]:
	"""Get all cards from opponent's hand that can be cast within budget"""
	var castable: Array[Card] = []
	
	for card_node in hand_cards:
		if card_node is Card:
			var card: Card = card_node as Card
			if card.cardData and card.cardData.goldCost <= budget:
				# TODO: Add more complex castability checks (additional costs, etc.)
				castable.append(card)
	
	return castable

func _find_target_location(card: Card) -> Node3D:
	"""Find a suitable target location for the opponent to cast a card"""
	if not card or not card.cardData:
		return null
	
	# For creatures, find an empty combat zone on the enemy side
	if card.cardData.hasType(CardData.CardType.CREATURE):
		return _find_random_empty_enemy_location()
	
	# For spells, return a generic target (spells don't need specific locations)
	# The spell targeting will be handled by the existing spell system
	return game.player_base  # Spells can be "cast" targeting the player base area
	
func _find_random_empty_enemy_location() -> CombatantFightingSpot:
	"""Find a random empty location on the enemy side of combat zones"""
	var available_locations: Array[CombatantFightingSpot] = []
	
	# Collect all empty enemy locations
	for combat_zone in game.combatZones:
		var empty_location = combat_zone.getFirstEmptyLocation(false)  # false = enemy side
		if empty_location:
			available_locations.append(empty_location)
	
	if available_locations.is_empty():
		return null
	
	# Return a random available location
	return available_locations[randi() % available_locations.size()]
