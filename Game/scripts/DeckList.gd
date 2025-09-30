extends Resource
class_name DeckList

var deck_cards: Array[CardData] = []
var extra_deck_cards: Array[CardData] = []

func _init(_deck_cards: Array[CardData] = [], _extra_deck_cards: Array[CardData] = []):
	deck_cards = _deck_cards
	extra_deck_cards = _extra_deck_cards
