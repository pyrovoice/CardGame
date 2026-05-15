extends Resource
class_name PlayerDeckBuildingData

# Maximum copies per (color, rarity) pair.
# Key format: "<Color int>_<Rarity int>" (e.g. "5_0" = RED_COMMON)
# Values start at 0 and are increased by in-run events.
var color_rarity_limits: Dictionary = {}

# All card names the player currently owns (unique names only).
var owned_card_names: Array[String] = []

# Player overrides: card_name -> desired copy count.
# Only entries that differ from the calculated maximum are stored here.
var player_modifications: Dictionary = {}  # String -> int

# ---------------------------------------------------------------------------
# Limit helpers
# ---------------------------------------------------------------------------

func _limit_key(color: CardData.CardColor, rarity: CardData.Rarity) -> String:
	return str(int(color)) + "_" + str(int(rarity))

func get_limit(color: CardData.CardColor, rarity: CardData.Rarity) -> int:
	return color_rarity_limits.get(_limit_key(color, rarity), 0)

func set_limit(color: CardData.CardColor, rarity: CardData.Rarity, count: int) -> void:
	color_rarity_limits[_limit_key(color, rarity)] = max(0, count)

func increase_limit(color: CardData.CardColor, rarity: CardData.Rarity, amount: int = 1) -> void:
	var key = _limit_key(color, rarity)
	color_rarity_limits[key] = max(0, color_rarity_limits.get(key, 0) + amount)

# ---------------------------------------------------------------------------
# Card ownership
# ---------------------------------------------------------------------------

func add_owned_card(card_name: String) -> void:
	if card_name not in owned_card_names:
		owned_card_names.append(card_name)

func remove_owned_card(card_name: String) -> void:
	owned_card_names.erase(card_name)
	player_modifications.erase(card_name)

func owns_card(card_name: String) -> bool:
	return card_name in owned_card_names

# ---------------------------------------------------------------------------
# Player modifications
# ---------------------------------------------------------------------------

# Override how many copies of a specific card go into the deck.
# Pass -1 to reset back to the calculated maximum.
func set_card_count_override(card_name: String, count: int) -> void:
	if count < 0:
		player_modifications.erase(card_name)
		return

	var max_count = get_max_copies_for_card(card_name)
	var clamped = min(count, max_count)

	if clamped == max_count:
		# No need to store — same as default
		player_modifications.erase(card_name)
	else:
		player_modifications[card_name] = clamped

# Returns the override if one exists, otherwise -1.
func get_card_count_override(card_name: String) -> int:
	return player_modifications.get(card_name, -1)

# ---------------------------------------------------------------------------
# Limit calculation per card
# ---------------------------------------------------------------------------

# Returns how many copies of a card should appear in the deck,
# applying the color/rarity rules and any player override.
func get_card_copy_count(card_name: String) -> int:
	var override = player_modifications.get(card_name, -1)
	if override >= 0:
		return override
	return get_max_copies_for_card(card_name)

# Returns the maximum copies allowed by the current limits for a card,
# ignoring any player override.
func get_max_copies_for_card(card_name: String) -> int:
	var card: CardData = CardLoaderAL.getCardByName(card_name)
	if not card:
		return 0
	return _limit_for_card(card)

func _limit_for_card(card: CardData) -> int:
	var rarity = card.rarity
	var best := 0

	if card.colors.is_empty():
		# Colorless: use highest limit across all non-NONE colors for this rarity
		for color_val in CardData.CardColor.values():
			best = max(best, get_limit(color_val as CardData.CardColor, rarity))
		return best

	if card.colors.size() == 1:
		return get_limit(card.colors[0], rarity)

	# Multi-color: use highest limit among the card's own colors
	for color in card.colors:
		best = max(best, get_limit(color, rarity))
	return best

# ---------------------------------------------------------------------------
# DeckList production
# ---------------------------------------------------------------------------

# Builds and returns a DeckList ready for use during combat.
# Requires a CardLoader to resolve card templates and create copies.
func build_deck_list() -> DeckList:
	var deck_cards: Array[CardData] = []
	var extra_deck_cards: Array[CardData] = []

	for card_name in owned_card_names:
		var count = get_card_copy_count(card_name)
		if count <= 0:
			continue

		# Fetch a fresh template each time; duplicateCardScript creates isolated copies
		var template: CardData = CardLoaderAL.getCardByName(card_name)
		if not template:
			push_warning("PlayerDeckBuildingData: owned card '%s' not found in CardLoader" % card_name)
			continue

		var is_legendary = template.hasType(CardData.CardType.LEGENDARY)
		for _i in range(count):
			var copy: CardData = CardLoaderAL.duplicateCardScript(template)
			if is_legendary:
				extra_deck_cards.append(copy)
			else:
				deck_cards.append(copy)

	return DeckList.new(deck_cards, extra_deck_cards)
