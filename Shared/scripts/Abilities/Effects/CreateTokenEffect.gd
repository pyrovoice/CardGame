extends Effect
class_name CreateTokenEffect

## Effect that creates token creatures
## Token count, destination, and script are parsed automatically by Effect._parse_parameters()

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	# token_script, num_cards, and dest_zone are already parsed by _parse_parameters()
	if token_script.is_empty():
		print("❌ No TokenScript specified for token creation")
		return []
	
	# Load the token data from the tokensData array
	var token_template = CardLoaderAL.getCardByName(token_script)
	if not token_template:
		print("❌ Failed to load token: " + token_script)
		return []
	
	var created: Array[CardData] = []
	# Create the tokens (num_cards is already set from parsing)
	for i in range(num_cards):
		# Create token data + view + movement through the centralized creation path.
		var token_data = game_context.createCardData(
			token_template,
			dest_zone,
			source_card_data.playerOwned
		)
		if not token_data:
			continue
		token_data.isToken = true
		
		# Flip token face up if going to battlefield (cards start face down by default)
		# Tokens in graveyard/hand/deck should remain face down
		if GameZone.is_in_play(dest_zone):
			var token_card = token_data.get_card_object()
			if token_card:
				token_card.setFlip(true)
		created.append(token_data)

	return created

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("TokenScript")

func get_description(parameters: Dictionary) -> String:
	var token_name = parameters.get("TokenScript", "Token")
	var num_tokens = parameters.get("NumCard", parameters.get("tokens_to_create", 1))
	if num_tokens == 1:
		return "Create a " + token_name + " token"
	else:
		return "Create " + str(num_tokens) + " " + token_name + " tokens"
