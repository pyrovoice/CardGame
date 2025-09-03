extends Resource
class_name CardData

# Define the card types
enum CardType { CREATURE, SPELL, PERMANENT }
	
var cardName: String
var cost: int
#Creature, spell, permanent
var type: CardType
#Goblin, Fire, Elemental... Can have up to 3
var subtypes: Array = []
var power: int
var text_box: String
#Contain all abilities from the card textBox to be useable by the game
var abilities: Array = []
# Card artwork texture
var cardArt: Texture2D

func _init(
	_cardName: String = "",
	_cost: int = 0,
	_type: CardType = CardType.CREATURE,
	_power: int = 0,
	_text_box: String = "",
	_subtypes: Array = []
) -> void:
	self.cardName = _cardName
	self.cost = _cost
	self.type = _type
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
	
	return "Card(name: %s, cost: %d, type: %s%s, power: %d%s, text: %s)" % [
		cardName,
		cost,
		CardType.keys()[type],
		subtypes_str,
		power,
		abilities_str,
		text_box
	]
	
func getTypeAsString() -> String:
	match type:
		CardType.CREATURE: return "Creature"
		CardType.SPELL: return "Spell"
		CardType.PERMANENT: return "Permanent"
	return "TYPE"

func getSubtypesAsString() -> String:
	"""Get subtypes as a space-separated string"""
	if subtypes.is_empty():
		return ""
	return " ".join(subtypes)

func getFullTypeString() -> String:
	"""Get the full type string including subtypes (e.g., 'Creature Goblin')"""
	var type_str = getTypeAsString()
	var subtype_str = getSubtypesAsString()
	if subtype_str != "":
		return type_str + " " + subtype_str
	return type_str
