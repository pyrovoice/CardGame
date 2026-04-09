extends Effect
class_name CreateTokenEffect

## Effect that creates token creatures
## Replacement effects should be handled at the ability level, not here

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var token_script = parameters.get("TokenScript", "")
	if token_script.is_empty():
		print("❌ No TokenScript specified for token creation")
		return
	
	# Load the token data from the tokensData array
	var token_template = CardLoaderAL.getCardByName(token_script)
	if not token_template:
		print("❌ Failed to load token: " + token_script)
		return
	
	# Get number of tokens to create (may have been modified by replacement effects)
	var tokens_to_create = parameters.get("tokens_to_create", 1)
	
	# Create the tokens
	for i in range(tokens_to_create):
		# Tokens enter the battlefield immediately on creation.
		var dest_zone = GameZone.e.BATTLEFIELD_PLAYER if source_card_data.playerControlled else GameZone.e.BATTLEFIELD_OPPONENT

		# Create token data + view + movement through the centralized creation path.
		var token_data = game_context.createCardData(
			token_template,
			dest_zone,
			source_card_data.playerOwned
		)
		if not token_data:
			continue
		token_data.isToken = true
		
		# Flip token face up (cards start face down by default)
		var token_card = token_data.get_card_object()
		if token_card:
			token_card.setFlip(true)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("TokenScript")

func get_description(parameters: Dictionary) -> String:
	var token_name = parameters.get("TokenScript", "Token")
	var num_tokens = parameters.get("tokens_to_create", 1)
	if num_tokens == 1:
		return "Create a " + token_name + " token"
	else:
		return "Create " + str(num_tokens) + " " + token_name + " tokens"
