extends RefCounted
class_name KeywordRegistry

## Game-logic keyword registry — mirrors EffectFactory for keywords.
## Owns the mapping from keyword name → Keyword instance.
##
## UI / reminder text is still KeywordManager's responsibility.
## This class only handles: on_apply hooks and load-time ability registration.

static var _registry: Dictionary = {}  # String → Keyword

static func _static_init() -> void:
	_register_all()

static func _register_all() -> void:
	_add(CorruptedKeyword.new())
	_add(ElusiveKeyword.new())
	_add(FleetingKeyword.new())

static func _add(kw: Keyword) -> void:
	_registry[kw.get_keyword_name()] = kw

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by CardModifier when a keyword is granted during gameplay.
## Automatically fires keyword.on_apply() if a handler is registered.
static func on_keyword_applied(card: CardData, keyword_name: String, game: Game) -> void:
	var kw: Keyword = _registry.get(keyword_name)
	if kw:
		kw.on_apply(card, game)

## Returns abilities for ALL keywords present on a card (used by CardLoader).
## Checks card._keywords and also asks each registered keyword whether it
## should register based on other signals (e.g. text_box detection).
static func get_all_abilities_for_card(card: CardData) -> Array[CardAbility]:
	var result: Array[CardAbility] = []
	var already_checked: Array[String] = []

	# Keywords explicitly in the card's base keyword list
	for kw_name in card._keywords:
		already_checked.append(kw_name)
		result.append_array(_get_abilities(kw_name, card))

	# Keywords that detect themselves from text_box or other means
	for kw_name in _registry:
		if kw_name in already_checked:
			continue
		var kw: Keyword = _registry[kw_name]
		if kw.should_register_for(card):
			result.append_array(kw.register_abilities(card))

	return result

## Get the Keyword instance for a given name, or null if not registered.
static func get_keyword(keyword_name: String) -> Keyword:
	return _registry.get(keyword_name)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

static func _get_abilities(keyword_name: String, card: CardData) -> Array[CardAbility]:
	var kw: Keyword = _registry.get(keyword_name)
	if kw:
		return kw.register_abilities(card)
	return []
