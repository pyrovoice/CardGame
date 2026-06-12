extends Node
## Global deck configuration that persists between scenes
## MainMenu sets this up before transitioning to game

var player_deck_building_data: PlayerDeckBuildingData = null

func setup_default_decks() -> void:
	player_deck_building_data = PlayerDeckBuildingData.new()

	# Starting limits: 1 copy per Red card at each rarity
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.COMMON, 3)
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.UNCOMMON, 2)
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.RARE, 1)
	player_deck_building_data.set_limit(CardData.CardColor.RED, CardData.Rarity.MYTHIC, 1)

	player_deck_building_data.add_owned_card("Punglynd Elder")
	player_deck_building_data.add_owned_card("Punglynd Childbearer")
	player_deck_building_data.add_owned_card("Punglynd Merchant")
	player_deck_building_data.add_owned_card("For those who come after")
	player_deck_building_data.add_owned_card("Warflag")
	player_deck_building_data.add_owned_card("Bolt")

func clear_decks() -> void:
	player_deck_building_data = null

func has_deck_configuration() -> bool:
	return player_deck_building_data != null
