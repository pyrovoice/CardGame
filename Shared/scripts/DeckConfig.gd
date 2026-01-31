extends Node
## Global deck configuration that persists between scenes
## MainMenu sets this up before transitioning to game

var player_deck_cards: Array[CardData] = []
var player_extra_deck_cards: Array[CardData] = []
var opponent_deck_cards: Array[CardData] = []

func setup_default_decks():
	"""Setup default deck lists with specific cards"""
	player_deck_cards = [
		CardLoaderAL.getCardByName("Goblin Emblem"),
		CardLoaderAL.getCardByName("Punglynd Childbearer"),
		CardLoaderAL.getCardByName("Goblin Warchief"),
		CardLoaderAL.getCardByName("Goblin Pair"),
		CardLoaderAL.getCardByName("Bolt")
	]
	player_extra_deck_cards = CardLoaderAL.extraDeckCardData.duplicate()
	
	# Necromancer default decklist
	opponent_deck_cards = [
		CardLoaderAL.getCardByName("Grave Whisperer")
	]

func clear_decks():
	"""Clear all deck lists (for tests)"""
	player_deck_cards.clear()
	player_extra_deck_cards.clear()
	opponent_deck_cards.clear()

func has_deck_configuration() -> bool:
	"""Check if any decks are configured"""
	return player_deck_cards.size() > 0 or player_extra_deck_cards.size() > 0 or opponent_deck_cards.size() > 0
