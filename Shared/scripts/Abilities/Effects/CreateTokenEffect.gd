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
	var token_data = CardLoaderAL.load_token_by_name(token_script)
	if not token_data:
		print("❌ Failed to load token: " + token_script)
		return
	
	# Get number of tokens to create (may have been modified by replacement effects)
	var tokens_to_create = parameters.get("tokens_to_create", 1)
	
	# Create the tokens
	for i in range(tokens_to_create):
		var card = game_context.createToken(token_data, source_card_data.playerControlled)
		game_context.executeCardEnters(card, GameZone.e.UNKNOWN, GameZone.e.UNKNOWN)

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("TokenScript")

func get_description(parameters: Dictionary) -> String:
	var token_name = parameters.get("TokenScript", "Token")
	var num_tokens = parameters.get("tokens_to_create", 1)
	if num_tokens == 1:
		return "Create a " + token_name + " token"
	else:
		return "Create " + str(num_tokens) + " " + token_name + " tokens"
