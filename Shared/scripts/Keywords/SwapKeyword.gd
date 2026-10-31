extends Keyword
class_name SwapKeyword

## Swap: You may play this card by returning an attacking creature you control to your hand
## and playing this card in its place at combat speed.
##
## Supports parameterized parsing:
## - Explicit K line: K: Swap | Cost$ 1 | Target$ Unblocked
## - CardText detection: "Swap {1} for an unblocked creature." or "Swap {1}"

func get_keyword_name() -> String:
	return "Swap"

func should_register_for(card: CardData) -> bool:
	if "Swap" in card._keywords:
		return true
	if card.text_box != "" and card.text_box.contains("Swap"):
		return true
	return false

func register_abilities(card: CardData) -> Array[CardAbility]:
	if "Swap" not in card._keywords:
		card._keywords.append("Swap")
	
	if not card.keyword_parameters.has("Swap"):
		var parsed = parse_swap_from_text(card.text_box)
		card.keyword_parameters["Swap"] = parsed
	
	return []

## Swap can be cast during combat while the player controls a valid creature to swap out.
## Whether the Swap cost can be paid is a resource question (CardPaymentManager.canAffordSwap).
func get_cast_permission(card: CardData, mode: ActionTiming.CastMode, timing: ActionTiming) -> ActionTiming.Permission:
	if mode != ActionTiming.CastMode.SWAP or not timing.is_combat_active():
		return ActionTiming.Permission.PASS
	if CardPaymentManagerAL.getValidSwapTargets(card).is_empty():
		return ActionTiming.Permission.PASS
	return ActionTiming.Permission.ALLOW

static func parse_swap_from_text(text: String) -> Dictionary:
	var result: Dictionary = {
		"cost": 1,
		"target": "attacking"
	}
	if text.is_empty():
		return result
	
	var regex := RegEx.new()
	# Matches "Swap {1}", "Swap 1", optionally followed by "for an? <target>"
	var err := regex.compile("(?i)Swap\\s*\\{?(\\d+)\\}?(?:\\s*for\\s*(?:an?\\s*)?([\\w\\s-]+?))?(?:\\.|\\n|$)")
	if err == OK:
		var m := regex.search(text)
		if m:
			if m.get_string(1) != "":
				result["cost"] = int(m.get_string(1))
			var target_str := m.get_string(2).strip_edges().to_lower()
			if target_str.contains("unblocked"):
				result["target"] = "unblocked"
			elif target_str != "":
				result["target"] = target_str
	return result
