extends Resource
class_name CardData

# Define the card types
enum CardType { CREATURE, SPELL, PERMANENT, BOSS }
	
var cardName: String
var goldCost: int
var additionalCosts: Array[Dictionary] = []  # Additional costs like sacrifice, etc.
#Creature, spell, permanent, boss - can have multiple types
var types: Array[CardType] = []
#Goblin, Fire, Elemental... Can have up to 3
var subtypes: Array = []
var power: int
var text_box: String
#Contain all abilities from the card textBox to be useable by the game
var abilities: Array[Dictionary] = []
# Card artwork texture
var cardArt: Texture2D

func _init(
	_cardName: String = "",
	_goldCost: int = 0,
	_types: Array[CardType] = [CardType.CREATURE],
	_power: int = 0,
	_text_box: String = "",
	_subtypes: Array = [],
	_additionalCosts: Array[Dictionary] = []
) -> void:
	self.cardName = _cardName
	self.goldCost = _goldCost
	self.additionalCosts = _additionalCosts.duplicate()
	self.types = _types.duplicate()
	self.power = _power
	self.text_box = _text_box
	self.subtypes = _subtypes.duplicate()
	
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
	match card_type:
		CardType.CREATURE: return "Creature"
		CardType.SPELL: return "Spell"
		CardType.PERMANENT: return "Permanent"
		CardType.BOSS: return "Boss"
	return "TYPE"

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

func addType(card_type: CardType):
	"""Add a type to this card if it doesn't already have it"""
	if card_type not in types:
		types.append(card_type)

func removeType(card_type: CardType):
	"""Remove a type from this card"""
	types.erase(card_type)

func isBossCreature() -> bool:
	"""Check if this card is both a Boss and a Creature"""
	return hasType(CardType.BOSS) and hasType(CardType.CREATURE)

func isSpell() -> bool:
	"""Check if this card is a Spell"""
	return hasType(CardType.SPELL)

func isCreature() -> bool:
	"""Check if this card is a Creature"""
	return hasType(CardType.CREATURE)

func isPermanent() -> bool:
	"""Check if this card is a Permanent"""
	return hasType(CardType.PERMANENT)

func isBoss() -> bool:
	"""Check if this card is a Boss"""
	return hasType(CardType.BOSS)

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
