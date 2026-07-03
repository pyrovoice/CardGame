extends Keyword
class_name CorruptedKeyword

## Handles all special effects for the Corrupted keyword.
##
## Effects fire in this order when Corrupted is applied to a creature:
##   1. on_apply  — power boost (+1 per gold cost) + switch control to player
##   2. On death  — add a random Punglynd_Corrupted card to the player's hand
##
## The "on combat received" effect is wired inline in game.gd's combat loop
## (after receiveDamage) because the STRIKE signal only carries the attacker,
## not what was struck.  See resolveCombatInZone in game.gd.

func get_keyword_name() -> String:
	return "Corrupted"

# ---------------------------------------------------------------------------
# on_apply — called automatically by KeywordRegistry via CardModifier.
# ---------------------------------------------------------------------------

func on_apply(card: CardData, game: Game) -> void:
	# Guard: run only once per card instance
	if card.has_meta("corrupted_applied"):
		return
	card.set_meta("corrupted_applied", true)

	print("☠️ [CORRUPTED] Applying to: ", card.cardName)

	# 1. Power boost: +1 might per gold cost
	if card.goldCost > 0:
		CardModifier.modify_card(card, "power_boost", {"amount": card.goldCost}, "Permanent")
		print("  ⚔️  Power +", card.goldCost, " (cost ", card.goldCost, ")")

	# 2. Switch control to the player
	card.playerOwned       = !card.playerOwned
	card.playerControlled  = !card.playerControlled
	card.dirty_data.emit()
	print("  🔄  Control switched — playerControlled: ", card.playerControlled)

	# 3. Register a one-shot death trigger: on death → add random Punglynd_Corrupted to hand
	_register_death_trigger(card, game)

# ---------------------------------------------------------------------------
# Called from game.gd's combat loop when a Corrupted creature is struck.
# Passing game to CardModifier means KeywordRegistry fires on_apply automatically.
# ---------------------------------------------------------------------------

static func on_combat_received(corrupted_card: CardData, attacker: CardData, game: Game) -> void:
	if not attacker:
		return
	if randf() < 0.5:
		print("☠️ [CORRUPTED] Spreading to: ", attacker.cardName)
		# game context passed → CardModifier calls KeywordRegistry.on_keyword_applied → on_apply
		CardModifier.modify_card(attacker, "keyword", {"keyword": "Corrupted"}, "Permanent", game)

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _register_death_trigger(card: CardData, game: Game) -> void:
	var ability := TriggeredAbility.new(
		card,
		TriggeredAbility.GameEventType.CARD_DIED,
		EffectType.Type.CREATE_CARD,
		game
	)
	# Pool$ Archetype.Punglynd_Corrupted → CreateCardEffect picks a random card from that pool
	ability.effect_parameters = {
		"Pool": "Punglynd_Corrupted",
		"Num":  1,
	}
	ability.one_shot = true
	game.register_orphaned_ability(ability)
	print("  💀  Death trigger registered for: ", card.cardName)
