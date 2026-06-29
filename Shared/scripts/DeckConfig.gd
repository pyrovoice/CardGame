extends Node
## Global deck configuration that persists between scenes
## MainMenu sets this up before transitioning to game

var player_deck_building_data: PlayerDeckBuildingData = null

func setup_default_decks() -> void:
	load_deck_from_file("res://DeckData/Punglynd.json")

func load_deck_from_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DeckConfig: could not open deck file: " + path)
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("DeckConfig: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return

	var data: Dictionary = json.get_data()
	player_deck_building_data = PlayerDeckBuildingData.new()

	for entry in data.get("limits", []):
		var color = _parse_color(entry.get("color", ""))
		var rarity = _parse_rarity(entry.get("rarity", ""))
		var count: int = entry.get("count", 0)
		player_deck_building_data.set_limit(color, rarity, count)

	for card_name in data.get("cards", []):
		player_deck_building_data.add_owned_card(card_name)

func _parse_color(color_str: String) -> CardData.CardColor:
	match color_str.to_lower():
		"blue":  return CardData.CardColor.BLUE
		"black": return CardData.CardColor.BLACK
		"green": return CardData.CardColor.GREEN
		"white": return CardData.CardColor.WHITE
		"red":   return CardData.CardColor.RED
		_:       return CardData.CardColor.NONE

func _parse_rarity(rarity_str: String) -> CardData.Rarity:
	match rarity_str.to_lower():
		"uncommon": return CardData.Rarity.UNCOMMON
		"rare":     return CardData.Rarity.RARE
		"mythic":   return CardData.Rarity.MYTHIC
		_:          return CardData.Rarity.COMMON

func clear_decks() -> void:
	player_deck_building_data = null

func has_deck_configuration() -> bool:
	return player_deck_building_data != null
