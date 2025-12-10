class_name CardData extends Resource

# Signal emitted when card data changes (types, subtypes, damage, etc.)
signal dirty_data

# Define the card types
enum CardType { CREATURE, SPELL, RELIC, LEGENDARY, TOKEN }
	
var cardName: String
var goldCost: int
var additionalCosts: Array[Dictionary] = []  # Additional costs like sacrifice, etc.
#Creature, spell, permanent, boss - can have multiple types
var types: Array[CardType] = []
#Goblin, Fire, Elemental... Can have up to 3
var subtypes: Array[String] = []
var power: int
var text_box: String
#Contain all abilities from the card textBox to be useable by the game
var abilities: Array[Dictionary] = []
# Card artwork texture
var cardArt: Texture2D
# Controller and ownership properties
var playerControlled: bool  # Whether this card is controlled by the player
var playerOwned: bool       # Whether this card is owned by the player

# Movement tracking
var hasMoved: bool = false  # Track if the card has moved this turn
# Attack tracking
var hasAttackedThisTurn: bool = false  # Track if the card attacked this turn

	
func describe() -> String:
	var subtypes_str = ""
	if subtypes.size() > 0:
		subtypes_str = ", subtypes: [" + ", ".join(subtypes) + "]"
	
	var abilities_str = ""
	if abilities.size() > 0:
		abilities_str = ", abilities: " + str(abilities.size())
	
	var additional_costs_str = ""
	if hasAdditionalCosts():
		additional_costs_str = ", additional costs: " + getAdditionalCostDescription()
	
	var types_str = getTypesAsString()
	
	return "Card(name: %s, goldCost: %d, types: %s%s, power: %d%s%s, text: %s)" % [
		cardName,
		goldCost,
		types_str,
		subtypes_str,
		power,
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
	if types.is_empty():
		return ""
	var type_strings: Array[String] = []
	for card_type in types:
		type_strings.append(getTypeAsString(card_type))
	return " ".join(type_strings)

func getSubtypesAsString() -> String:
	"""Get subtypes as a space-separated string"""
	if subtypes.is_empty():
		return ""
	return " ".join(subtypes)

func getFullTypeString() -> String:
	"""Get the full type string including subtypes (e.g., 'Boss Creature Goblin')"""
	var types_str = getTypesAsString()
	var subtype_str = getSubtypesAsString()
	if subtype_str != "":
		return types_str + " " + subtype_str
	return types_str

func hasType(card_type: CardType) -> bool:
	"""Check if this card has a specific type"""
	return card_type in types

func hasSubtype(card_type: String) -> bool:
	"""Check if this card has a specific type"""
	return card_type in subtypes
	
func addType(card_type: CardType):
	"""Add a type to this card if it doesn't already have it"""
	if card_type not in types:
		types.append(card_type)
		dirty_data.emit()

func addSubtype(subtype: String):
	"""Add a subtype to this card if it doesn't already have it"""
	if subtype not in subtypes:
		subtypes.append(subtype)
		dirty_data.emit()

func removeType(card_type: CardType):
	"""Remove a type from this card"""
	if card_type in types:
		types.erase(card_type)
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

# Movement and attack tracking methods
func reset_movement_tracking():
	"""Reset movement tracking at the start of turn"""
	hasMoved = false

func mark_as_moved():
	"""Mark this card as having moved this turn"""
	hasMoved = true

func reset_attack_tracking():
	"""Reset attack tracking at the start of turn"""
	hasAttackedThisTurn = false

func mark_as_attacked():
	"""Mark this card as having attacked this turn"""
	hasAttackedThisTurn = true

func reset_turn_tracking():
	"""Reset all turn-based tracking (movement, attacks, etc.) at start of turn"""
	reset_movement_tracking()
	reset_attack_tracking()
