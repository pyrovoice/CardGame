extends Node
## Global deck configuration that persists between scenes
## MainMenu sets this up before transitioning to game

var player_deck_cards: Array[CardData] = []
var player_extra_deck_cards: Array[CardData] = []
var opponent_deck_cards: Array[CardData] = []

func setup_default_decks():
	"""Setup default deck lists - Punglynd archetype + Bolt"""
	# Get all Punglynd archetype cards (non-legendary)
	var punglynd_pool = CardLoaderAL.get_archetype_pool(CardLoader.Archetype.PUNGLYND)
	print("🔍 [DECK] Punglynd archetype pool has ", punglynd_pool.size(), " cards")
	for card in punglynd_pool:
		print("    - ", card.cardName, " (", card.goldCost, " gold, legendary: ", card.hasType(CardData.CardType.LEGENDARY), ")")
	
	player_deck_cards = []
	player_extra_deck_cards = []
	
	for card in punglynd_pool:
		if card.hasType(CardData.CardType.LEGENDARY):
			# Legendary cards go to extra deck
			player_extra_deck_cards.append(card)
		else:
			# Non-legendary cards go to main deck
			player_deck_cards.append(card)
	
	# Add Bolt spell
	var bolt_card = CardLoaderAL.getCardByName("Bolt")
	if bolt_card:
		player_deck_cards.append(bolt_card)
	
	# Necromancer default decklist
	opponent_deck_cards = [
		CardLoaderAL.getCardByName("Grave Whisperer")
	]
	
	print("📋 Player deck configured with Punglynd archetype:")
	print("  Main deck (", player_deck_cards.size(), " cards):")
	for card in player_deck_cards:
		print("    - ", card.cardName, " (", card.goldCost, " gold)")
	print("  Extra deck (", player_extra_deck_cards.size(), " legendary cards)")
	for card in player_extra_deck_cards:
		print("    - ", card.cardName, " (", card.goldCost, " gold)")

func clear_decks():
	"""Clear all deck lists (for tests)"""
	player_deck_cards.clear()
	player_extra_deck_cards.clear()
	opponent_deck_cards.clear()

func has_deck_configuration() -> bool:
	"""Check if any decks are configured"""
	return player_deck_cards.size() > 0 or player_extra_deck_cards.size() > 0 or opponent_deck_cards.size() > 0
