extends Node
## Global deck configuration that persists between scenes
## MainMenu sets this up before transitioning to game

var player_deck_building_data: PlayerDeckBuildingData = null

func setup_default_decks() -> void:
	player_deck_building_data = PlayerDeckBuildingData.new()

	# Starting limits: 1 copy per Red card at each rarity
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.COMMON, 4)
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.UNCOMMON, 1)
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.RARE, 1)
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.MYTHIC, 1)

	# Own all Punglynd archetype cards
	var punglynd_pool = CardLoaderAL.get_archetype_pool(CardLoader.Archetype.PUNGLYND)
	for card in punglynd_pool:
		player_deck_building_data.add_owned_card(card.cardName)

	# Own Bolt
	player_deck_building_data.add_owned_card("Bolt")

func clear_decks() -> void:
	player_deck_building_data = null

func has_deck_configuration() -> bool:
	return player_deck_building_data != null
