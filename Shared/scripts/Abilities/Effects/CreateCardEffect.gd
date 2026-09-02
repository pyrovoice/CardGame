extends Effect
class_name CreateCardEffect

## Effect that creates a card from an archetype pool and adds it to hand

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# pool, include_legendary, num_cards, and modif are already parsed by _parse_parameters()
	if pool.is_empty():
		print("❌ No Pool specified for card creation")
		return []
	
	# Parse the pool — try archetype pool first, then named card pool
	var archetype_enum = _parse_archetype_pool(pool)
	var card_pool: Array[CardData]
	if archetype_enum != CardLoader.Archetype.UNKNOWN:
		card_pool = CardLoaderAL.get_archetype_pool(archetype_enum)
	else:
		# Strip "Archetype." prefix and look up named pool
		var pool_name = pool
		if pool.begins_with("Archetype."):
			pool_name = pool.substr(10)
		card_pool = CardLoaderAL.get_card_pool(pool_name)

	if card_pool.is_empty():
		print("⚠️ Card pool '", pool, "' is empty or unknown")
		return []
	
	# Filter out legendary cards unless explicitly included
	if not include_legendary:
		card_pool = card_pool.filter(func(card: CardData): return not card.hasType(CardData.CardType.LEGENDARY))
		if card_pool.is_empty():
			print("⚠️ Archetype pool '", pool, "' has no non-legendary cards")
			return []
	
	var created: Array[CardData] = []
	# Create the cards
	for i in range(num_cards):
		# Add to appropriate hand
		var dest_zone = GameZone.e.HAND_PLAYER if source_card_data.playerControlled else GameZone.e.HAND_OPPONENT

		# Pick a random card from the pool
		var random_index = randi() % card_pool.size()
		var template_card: CardData = card_pool[random_index]
		
		# Create card data + view + movement through the centralized creation path.
		var new_card_data = game_context.createCardData(
			template_card,
			dest_zone,
			source_card_data.playerOwned
		)
		if not new_card_data:
			continue
		
		# Apply modifiers if specified (e.g., "fleeting")
		if not modif.is_empty():
			_apply_modifier_to_card(new_card_data, modif)
		
		print("✨ Created card '", new_card_data.cardName, "' from archetype '", pool, "' into hand")
		created.append(new_card_data)

	return created

func _apply_modifier_to_card(card_data: CardData, modifier: String):
	"""Apply a modifier (like 'fleeting') to a created card"""
	# Add the modifier as a keyword
	# The add_keyword() method will automatically emit dirty_data signal
	# which triggers Card to update its display
	card_data.add_keyword(modifier)
	print("  ✨ Applied modifier '", modifier, "' to ", card_data.cardName)

func _parse_archetype_pool(pool_string: String) -> CardLoader.Archetype:
	"""Parse pool string like 'Archetype.Punglynd' into CardLoader.Archetype enum"""
	# Remove "Archetype." prefix if present
	var archetype_name = pool_string
	if pool_string.begins_with("Archetype."):
		archetype_name = pool_string.substr(10)  # Remove "Archetype." prefix
	
	# Convert to uppercase for matching
	archetype_name = archetype_name.to_upper()
	
	# Match to enum
	match archetype_name:
		"PUNGLYND":
			return CardLoader.Archetype.PUNGLYND
		"NECROMANCER":
			return CardLoader.Archetype.NECROMANCER
		_:
			return CardLoader.Archetype.UNKNOWN

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Pool")

func get_description(parameters: Dictionary) -> String:
	var pool_name = parameters.get("Pool", "unknown")
	var num_cards = parameters.get("Num", 1)
	if num_cards == 1:
		return "Create a random card from " + pool_name + " in hand"
	else:
		return "Create " + str(num_cards) + " random cards from " + pool_name + " in hand"
