extends Effect
class_name CreateCardEffect

## Effect that creates a card from an archetype pool and adds it to hand

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var pool_string = parameters.get("Pool", "")
	if pool_string.is_empty():
		print("❌ No Pool specified for card creation")
		return
	
	# Parse the pool - expecting format like "Archetype.Punglynd"
	var archetype_enum = _parse_archetype_pool(pool_string)
	if archetype_enum == CardLoader.Archetype.UNKNOWN:
		print("❌ Unknown or invalid archetype pool: ", pool_string)
		return
	
	# Get the card pool for this archetype
	var card_pool: Array[CardData] = CardLoaderAL.get_archetype_pool(archetype_enum)
	if card_pool.is_empty():
		print("⚠️ Archetype pool '", pool_string, "' is empty")
		return
	
	# Get number of cards to create
	var num_cards = int(parameters.get("Num", 1))
	
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
		
		print("✨ Created card '", new_card_data.cardName, "' from archetype '", pool_string, "' into hand")

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
