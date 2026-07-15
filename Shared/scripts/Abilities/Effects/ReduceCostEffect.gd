extends Effect
class_name ReduceCostEffect

## Permanently reduces the gold cost of a target card.
## Intended for "if you do" follow-ups (e.g., after Recycle: that card costs 1 less).
##
## Parameters:
##   Defined (String) — target selector. Supported: "LastDrafted"
##   Amount (int, default 1) — how much to reduce the cost

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game) -> Array[CardData]:
	var amount: int = parameters.get("Amount", 1)
	var defined: String = parameters.get("Defined", "")

	var target: CardData = _resolve_target(defined, game_context)
	if not target:
		push_error("ReduceCostEffect: could not resolve target for Defined$ '" + defined + "'")
		return []

	target.goldCost = max(0, target.goldCost - amount)
	target.dirty_data.emit()
	print("💰 [REDUCE_COST] ", target.cardName, " cost reduced by ", amount, " → now costs ", target.goldCost)
	return [target]

func _resolve_target(defined: String, game_context: Game) -> CardData:
	match defined:
		"LastDrafted":
			return game_context.last_drafted_card
		_:
			push_error("ReduceCostEffect: unsupported Defined$ value: '" + defined + "'")
			return null

func validate_parameters(parameters: Dictionary) -> bool:
	return parameters.has("Defined")

func get_description(parameters: Dictionary) -> String:
	var amount = parameters.get("Amount", 1)
	return "That card costs " + str(amount) + " less"
