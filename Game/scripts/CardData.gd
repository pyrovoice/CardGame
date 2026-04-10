class_name CardData extends Resource

# Signal emitted when card data changes (types, subtypes, damage, etc.)
signal dirty_data

# Define the card types
enum CardType { CREATURE, SPELL, RELIC, LEGENDARY, TOKEN }
	
var cardName: String
var goldCost: int

# Core properties with _ prefix are modified through _get() interception
var _types: Array[CardType] = []
#Goblin, Fire, Elemental... Can have up to 3
var _subtypes: Array[String] = []
var _power: int
var text_box: String
# Abilities from the card textBox - split by type for clarity and type safety
var triggered_abilities: Array[TriggeredAbility] = []
var activated_abilities: Array[ActivatedAbility] = []
var static_abilities: Array[StaticAbility] = []  # S: effects - continuous effects like "Goblins get +1 power"
var replacement_abilities: Array[ReplacementAbility] = []  # R: effects - replacement effects like "create one more token"
var spell_abilities: Array[SpellAbility] = []
# Keyword abilities (separate from complex abilities)
var _keywords: Array[String] = []  # Simple keywords like "Flying", "Spellshield"
# Additional costs beyond gold cost (sacrifice, replace, etc.)
var additionalCosts: Array[Dictionary] = []
# Card artwork texture
var cardArt: Texture2D
# Controller and ownership properties
var playerControlled: bool  # Whether this card is controlled by the player
var playerOwned: bool       # Whether this card is owned by the player
var card_object: WeakRef  # Reference to Card object (using WeakRef to avoid cycles)
var hasAttackedThisTurn: bool = false  # Track if the card attacked this turn
var isTapped: bool = false  # Track if the card is currently tapped
var temporary_effects: Array[TemporaryEffect] = []  # Track temporary effects applied to this card
var isToken = false
var current_zone: GameZone.e = GameZone.e.UNKNOWN  # Current zone this card is in (set by GameData)
var damage: int = 0  # Damage dealt to this card this turn

func receiveDamage(v: int):
	damage += v
	dirty_data.emit()

func getDamage() -> int:
	return damage

func reset_damage():
	damage = 0
	dirty_data.emit()

## Property interception - automatically applies temporary effects
func _get(property):
	"""Intercept property reads to apply temporary effects"""
	# Don't intercept properties that already start with underscore (base properties)
	if property.begins_with("_"):
		return null  # Let normal property access continue
	
	var base_prop = "_" + property
	
	# Check if this is a managed property
	if base_prop in self:
		# get() will call _get("_power") which returns null, allowing normal access
		var base_value = get(base_prop)
		return _apply_modification_layers(property, base_value)
	
	return null  # Let normal property access continue

func _set(property, value):
	"""Intercept property writes to redirect to base properties"""
	# Don't intercept properties that already start with underscore
	if property.begins_with("_"):
		return false  # Let normal property assignment continue
	
	var base_prop = "_" + property
	
	# Check if this is a managed property
	if base_prop in self:
		# set() will call _set("_power") which returns false, allowing normal access
		set(base_prop, value)
		return true
	
	return false  # Let normal property assignment continue

func _apply_modification_layers(property_name: String, base_value):
	"""Apply temporary effect modifications in layers"""
	var result = base_value
	
	# For arrays, duplicate to avoid modifying base
	if result is Array:
		result = result.duplicate()
	
	# Layer 1: Additive modifications
	for effect in temporary_effects:
		if effect.property_name == property_name and effect.modification_type == TemporaryEffect.ModificationType.ADDITIVE:
			result = _apply_additive_effect(result, effect)
	
	# Layer 2: Replacement effects (override everything)
	for effect in temporary_effects:
		if effect.property_name == property_name and effect.modification_type == TemporaryEffect.ModificationType.REPLACEMENT:
			result = effect.replacement_value
			break  # First replacement wins
	
	return result

func _apply_additive_effect(current_value, effect: TemporaryEffect):
	"""Apply an additive effect based on the value type"""
	if current_value is int:
		# For power, add the bonus
		return current_value + effect.power_bonus
	elif current_value is Array:
		# For keywords/types/subtypes, add to array
		if effect.keyword != "" and effect.keyword not in current_value:
			current_value.append(effect.keyword)
		elif effect.type_to_add != "":
			var card_type = CardData.stringToCardType(effect.type_to_add)
			if card_type not in current_value:
				current_value.append(card_type)
		elif effect.subtype_to_add != "" and effect.subtype_to_add not in current_value:
			current_value.append(effect.subtype_to_add)
	
	return current_value
	
func describe() -> String:
	var subtypes_str = ""
	if self.subtypes.size() > 0:
		subtypes_str = ", subtypes: [" + ", ".join(self.subtypes) + "]"
	
	var abilities_str = ""
	var total_abilities = triggered_abilities.size() + activated_abilities.size() + static_abilities.size() + replacement_abilities.size() + spell_abilities.size()
	if total_abilities > 0:
		abilities_str = ", abilities: " + str(total_abilities)
	
	var additional_costs_str = ""
	if hasAdditionalCosts():
		additional_costs_str = ", additional costs: " + getAdditionalCostDescription()
	
	var types_str = getTypesAsString()
	
	return "Card(name: %s, goldCost: %d, types: %s%s, power: %d%s%s, text: %s)" % [
		cardName,
		goldCost,
		types_str,
		subtypes_str,
		self.power,  # Use property accessor to get modified value
		abilities_str,
		additional_costs_str,
		text_box
	]
	
func getTypeAsString(card_type: CardType) -> String:
	"""Convert a single CardType enum to string"""
	return CardData.cardTypeToString(card_type)

# Static utility methods for CardType conversions
static func cardTypeToString(card_type: CardType) -> String:
	"""Convert a CardType enum to string - centralized conversion"""
	match card_type:
		CardType.CREATURE: return "Creature"
		CardType.SPELL: return "Spell"
		CardType.RELIC: return "Relic"
		CardType.LEGENDARY: return "Legendary"
		CardType.TOKEN: return "Token"
	return "Unknown"

static func stringToCardType(type_string: String) -> CardType:
	"""Convert a string to CardType enum - centralized conversion"""
	match type_string.strip_edges():
		"Creature": return CardType.CREATURE
		"Spell": return CardType.SPELL
		"Relic": return CardType.RELIC
		"Legendary": return CardType.LEGENDARY
		"Token": return CardType.TOKEN
	push_error("Unknown card type string: " + type_string)
	return CardType.CREATURE  # Default fallback

static func isValidCardTypeString(type_string: String) -> bool:
	"""Check if a string represents a valid card type"""
	match type_string.strip_edges():
		"Creature", "Spell", "Relic", "Legendary", "Token":
			return true
	return false

static func getAllCardTypeStrings() -> Array[String]:
	"""Get all valid card type strings for validation/UI purposes"""
	return ["Creature", "Spell", "Relic", "Legendary", "Token"]

func getTypesAsString() -> String:
	"""Get all types as a space-separated string"""
	var current_types = self.types  # Use property accessor
	if current_types.is_empty():
		return ""
	var type_strings: Array[String] = []
	for card_type in current_types:
		type_strings.append(getTypeAsString(card_type))
	return " ".join(type_strings)

func getSubtypesAsString() -> String:
	"""Get subtypes as a space-separated string"""
	var current_subtypes = self.subtypes  # Use property accessor
	if current_subtypes.is_empty():
		return ""
	return " ".join(current_subtypes)

func getFullTypeString() -> String:
	"""Get the full type string including subtypes (e.g., 'Boss Creature Goblin')"""
	var types_str = getTypesAsString()
	var subtype_str = getSubtypesAsString()
	if subtype_str != "":
		return types_str + " " + subtype_str
	return types_str

func hasType(card_type: CardType) -> bool:
	"""Check if this card has a specific type (including temporary types)"""
	return card_type in self.types  # Use property accessor

func hasSubtype(card_type: String) -> bool:
	"""Check if this card has a specific subtype (including temporary subtypes)"""
	return card_type in self.subtypes  # Use property accessor
	
func addType(card_type: CardType):
	"""Add a type to this card if it doesn't already have it"""
	if card_type not in _types:
		_types.append(card_type)
		dirty_data.emit()

func addSubtype(subtype: String):
	"""Add a subtype to this card if it doesn't already have it"""
	if subtype not in _subtypes:
		_subtypes.append(subtype)
		dirty_data.emit()

func removeType(card_type: CardType):
	"""Remove a type from this card"""
	if card_type in _types:
		_types.erase(card_type)
		dirty_data.emit()

func hasAdditionalCosts() -> bool:
	"""Check if this card has any additional costs beyond gold"""
	return not additionalCosts.is_empty()

func getAdditionalCosts() -> Array[Dictionary]:
	"""Get all additional costs for this card"""
	return additionalCosts.duplicate()

func addAdditionalCost(cost_data: Dictionary):
	"""Add an additional cost to this card"""
	additionalCosts.append(cost_data)

func getAdditionalCostDescription() -> String:
	"""Get a human-readable description of additional costs"""
	if additionalCosts.is_empty():
		return ""
	
	var descriptions: Array[String] = []
	for cost in additionalCosts:
		var desc = _formatAdditionalCostDescription(cost)
		if desc != "":
			descriptions.append(desc)
	
	return ", ".join(descriptions)

func _formatAdditionalCostDescription(cost_data: Dictionary) -> String:
	"""Format a single additional cost for display"""
	if not cost_data.has("cost_type"):
		return ""
	
	match cost_data.get("cost_type", ""):
		"SacrificePermanent":
			var count = cost_data.get("count", 1)
			var valid_card = cost_data.get("valid_card", "Card")
			return "Sacrifice %d %s" % [count, _formatValidCardDescription(valid_card)]
		_:
			return "Additional cost"

func _formatValidCardDescription(valid_card: String) -> String:
	"""Format ValidCard string for human reading"""
	# Convert "Card.YouCtrl+Goblin" to "Goblin you control"
	var parts = valid_card.split("+")
	var descriptors: Array[String] = []
	var has_you_ctrl = false
	
	for part in parts:
		if part.contains("YouCtrl"):
			has_you_ctrl = true
		elif part != "Card":
			descriptors.append(part)
	
	var result = " ".join(descriptors) if not descriptors.is_empty() else "permanent"
	if has_you_ctrl:
		result += " you control"
	
	return result


func reset_attack_tracking():
	"""Reset attack tracking at the start of turn"""
	hasAttackedThisTurn = false

func reset_turn_tracking():
	"""Reset all turn-based tracking (movement, attacks, etc.) at start of turn"""
	reset_attack_tracking()

# Tap state methods
func tap():
	"""Tap this card"""
	isTapped = true
	emit_signal("dirty_data")

func untap():
	"""Untap this card"""
	isTapped = false
	emit_signal("dirty_data")

func is_tapped() -> bool:
	"""Check if this card is currently tapped"""
	return isTapped

func can_tap() -> bool:
	"""Check if this card can be tapped (i.e., is not already tapped)"""
	return not isTapped

# Temporary effects tracking methods
func add_temporary_effect(effect: TemporaryEffect):
	"""Add a temporary effect to this card"""
	temporary_effects.append(effect)

func subscribe_to_game_signals(game: Node):
	"""Subscribe to game signals and register all abilities"""
	# Register all triggered abilities to game signals
	for ability in triggered_abilities:
		ability.register_to_game(game)
	
	# Apply static abilities to game
	for ability in static_abilities:
		ability.apply_to_game(game)
	
	# Register replacement effects
	for ability in replacement_abilities:
		ability.apply_to_game(game)
	
	# Subscribe to end_of_turn for temporary effect cleanup
	# Note: All cards subscribe since they can gain temporary effects at any time
	if game.has_signal("end_of_turn"):
		if not game.is_connected("end_of_turn", _on_end_of_turn):
			game.end_of_turn.connect(_on_end_of_turn)

func unsubscribe_from_game_signals(game: Node):
	"""Unsubscribe from game signals when card is removed"""
	if game and is_instance_valid(game):
		if game.has_signal("end_of_turn") and game.is_connected("end_of_turn", _on_end_of_turn):
			game.end_of_turn.disconnect(_on_end_of_turn)

func _on_end_of_turn(event_card_data: CardData = null):
	"""Handle end of turn cleanup for temporary effects"""
	var effects_to_remove = get_temporary_effects_by_duration(TemporaryEffect.Duration.END_OF_TURN)
	
	if effects_to_remove.size() > 0:
		print("  🗑️ [CARDDATA] ", cardName, " removing ", effects_to_remove.size(), " end-of-turn effect(s)")
		
		for effect in effects_to_remove:
			clear_temporary_effect(effect)
		
		dirty_data.emit()

func has_temporary_effects() -> bool:
	"""Check if this card has any temporary effects"""
	return temporary_effects.size() > 0

func has_temporary_effect(effect_type: EffectType.Type) -> bool:
	"""Check if this card has a temporary effect of a specific type"""
	for effect in temporary_effects:
		if effect.matches_type(effect_type):
			return true
	return false

func get_temporary_effects_by_duration(duration: TemporaryEffect.Duration) -> Array[TemporaryEffect]:
	"""Get all temporary effects with a specific duration"""
	var matching_effects: Array[TemporaryEffect] = []
	for effect in temporary_effects:
		if effect.matches_duration(duration):
			matching_effects.append(effect)
	return matching_effects

func clear_temporary_effect(effect: TemporaryEffect):
	"""Remove a specific temporary effect from this card"""
	temporary_effects.erase(effect)

# Card object reference methods
func set_card_object(card: Card):
	"""Set the Card object reference (uses WeakRef to avoid reference cycles)"""
	if card:
		card_object = weakref(card)
	else:
		card_object = null

func get_card_object() -> Card:
	"""Get the Card object if it still exists, null otherwise"""
	if card_object:
		var card = card_object.get_ref()
		if card and is_instance_valid(card):
			return card
	return null

## Ability management methods

func add_ability(ability: CardAbility):
	"""Add an ability to this card - routes to appropriate array based on type"""
	if ability is TriggeredAbility:
		triggered_abilities.append(ability)
	elif ability is ActivatedAbility:
		activated_abilities.append(ability)
	elif ability is ReplacementAbility:
		replacement_abilities.append(ability)
	elif ability is StaticAbility:
		static_abilities.append(ability)
	elif ability is SpellAbility:
		spell_abilities.append(ability)
	else:
		push_warning("Unknown ability type: " + str(ability))
	dirty_data.emit()

func get_all_abilities() -> Array[CardAbility]:
	"""Get all abilities combined (for backward compatibility)"""
	var all_abilities: Array[CardAbility] = []
	all_abilities.append_array(triggered_abilities)
	all_abilities.append_array(activated_abilities)
	all_abilities.append_array(static_abilities)
	all_abilities.append_array(replacement_abilities)
	all_abilities.append_array(spell_abilities)
	return all_abilities

func add_keyword(keyword: String):
	"""Add a keyword ability to this card"""
	if keyword not in _keywords:
		_keywords.append(keyword)
		dirty_data.emit()

func remove_keyword(keyword: String):
	"""Remove a keyword ability from this card"""
	if keyword in _keywords:
		_keywords.erase(keyword)
		dirty_data.emit()

func has_keyword(keyword: String) -> bool:
	"""Check if this card has a specific keyword (including temporary ones)"""
	return keyword in self.keywords  # Property accessor automatically includes temp effects
