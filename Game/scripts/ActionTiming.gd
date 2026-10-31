extends RefCounted
class_name ActionTiming

## Answers "can this card be cast / this ability be activated RIGHT NOW?" from timing alone.
## It never looks at resources; see CardPaymentManager.canAffordCard / canAffordActivation for that.
##
## Layer 1 - default window: cards are cast outside combat, activated abilities any time.
## Layer 2 - speed: a Fast card is cast any time; an ability with Slow$ True only outside combat.
## Layer 3 - permissions: keywords (e.g. Swap) can allow or deny a cast mode. Deny always wins.
##
## "In combat" lasts from the first player creature entering a combat zone until that
## location's resolution has fully completed (GameData.set_combat_started).

enum CastMode { NORMAL, SWAP }
enum Permission { PASS, ALLOW, DENY }

const ALL_CAST_MODES: Array[CastMode] = [CastMode.NORMAL, CastMode.SWAP]

var game: Game

func _init(p_game: Game) -> void:
	game = p_game

func is_combat_active() -> bool:
	return game.game_data.is_any_combat_started()

# ─── Casting ──────────────────────────────────────────────────────────────────

func get_cast_modes(card_data: CardData) -> Array[CastMode]:
	var modes: Array[CastMode] = []
	for mode in ALL_CAST_MODES:
		if can_cast_in_mode(card_data, mode):
			modes.append(mode)
	return modes

func can_cast_now(card_data: CardData) -> bool:
	return not get_cast_modes(card_data).is_empty()

func can_cast_in_mode(card_data: CardData, mode: CastMode) -> bool:
	if not card_data:
		return false
	var allowed := _is_in_default_cast_window(card_data, mode)
	for keyword_name in card_data.keywords:
		var keyword: Keyword = KeywordRegistry.get_keyword(keyword_name)
		if not keyword:
			continue
		match keyword.get_cast_permission(card_data, mode, self):
			Permission.DENY:
				return false
			Permission.ALLOW:
				allowed = true
	return allowed

func _is_in_default_cast_window(card_data: CardData, mode: CastMode) -> bool:
	# Alternative modes only exist when a keyword explicitly allows them
	if mode != CastMode.NORMAL:
		return false
	return card_data.has_keyword("Fast") or not is_combat_active()

# ─── Activation ───────────────────────────────────────────────────────────────

func can_activate_now(card_data: CardData, ability: ActivatedAbility) -> bool:
	if not card_data or not ability:
		return false
	if not GameZone.is_in_play(game.game_data.get_card_zone(card_data)):
		return false
	return not (ability.is_slow and is_combat_active())
