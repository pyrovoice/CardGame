extends Resource
class_name EncounterDeckList

## Holds the decks for all three Lieutenants and the Commander in one encounter.
## Loaded from DeckData/Opponents/<EncounterName>.json via load_from_file().

var encounter_name: String = ""
var aggro_deck: DeckList = DeckList.new()
var control_deck: DeckList = DeckList.new()
var combo_deck: DeckList = DeckList.new()
var commander_name: String = ""
var commander_deck: DeckList = DeckList.new()

static func load_from_file(path: String) -> EncounterDeckList:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EncounterDeckList: could not open file: " + path)
		return null

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("EncounterDeckList: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return null

	var data: Dictionary = json.get_data()
	var encounter = EncounterDeckList.new()
	encounter.encounter_name = data.get("name", "")

	var lieutenants: Dictionary = data.get("lieutenants", {})
	encounter.aggro_deck = _build_deck_list(lieutenants.get("aggro", []))
	encounter.control_deck = _build_deck_list(lieutenants.get("control", []))
	encounter.combo_deck = _build_deck_list(lieutenants.get("combo", []))

	var commander: Dictionary = data.get("commander", {})
	encounter.commander_name = commander.get("name", "")
	encounter.commander_deck = _build_deck_list(commander.get("cards", []))

	return encounter

# Expands {"card": name, "count": N} entries into N duplicated CardData templates each,
# mirroring PlayerDeckBuildingData.build_deck_list() so the deck can be replenished the same way.
static func _build_deck_list(entries: Array) -> DeckList:
	var deck_cards: Array[CardData] = []

	for entry in entries:
		var card_name: String = entry.get("card", "")
		var count: int = entry.get("count", 0)
		if card_name.is_empty() or count <= 0:
			continue

		var template: CardData = CardLoaderAL.getCardByName(card_name)
		if not template:
			push_warning("EncounterDeckList: card '%s' not found in CardLoader" % card_name)
			continue

		for _i in range(count):
			deck_cards.append(CardLoaderAL.duplicateCardScript(template))

	return DeckList.new(deck_cards)
