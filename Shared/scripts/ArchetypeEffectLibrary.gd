extends Object
class_name ArchetypeEffectLibrary

## Registry of archetype passive abilities.
## Each archetype defines one or more TriggeredAbility objects that are
## registered as permanent orphaned abilities at game start.
##
## Adding a new archetype:
##   1. Add an entry to _REGISTRY below.
##   2. Write a static func _create_<archetype>_abilities(game) -> Array[TriggeredAbility].
##
## The archetype ID is the lowercase name from the deck JSON ("name" field lowercased).

static func create_and_register(archetype_id: String, game: Game) -> void:
	if archetype_id.is_empty():
		return

	var abilities := _build(archetype_id, game)
	for ability in abilities:
		game.register_orphaned_ability(ability)

# ---------------------------------------------------------------------------
# Internal dispatch
# ---------------------------------------------------------------------------

static func _build(archetype_id: String, game: Game) -> Array[TriggeredAbility]:
	match archetype_id:
		"punglynd":
			return _create_punglynd_abilities(game)
		_:
			push_warning("ArchetypeEffectLibrary: no abilities defined for archetype '%s'" % archetype_id)
			return []

# ---------------------------------------------------------------------------
# Punglynd – "Dark Whisper"
# After the opponent's main phase, add Corrupted to a random opposing creature.
# ---------------------------------------------------------------------------

static func _create_punglynd_abilities(game: Game) -> Array[TriggeredAbility]:
	# Phantom source card that acts as the ability's owner for the whole game.
	var source := CardData.new()
	source.cardName = "Punglynd Archetype Power"

	var ability := TriggeredAbility.new(
		source,
		TriggeredAbility.GameEventType.OPPONENT_TURN_END,
		EffectType.Type.ADD_KEYWORD,
		game
	)
	ability.effect_parameters = {
		"KW":          "Corrupted",
		"Duration":    "Permanent",
		"ValidCards":  "Creature.Opponent",
		"NumCard":     1,
		"Choice":      "Random",
	}

	var result: Array[TriggeredAbility] = [ability]
	return result
