extends Resource
class_name CardData

# Define the card types
enum CardType { CREATURE, SPELL, PERMANENT }
	
var cardName: String
var cost: int
var type: CardType
var power: int
var text_box: String

func _init(
	cardName: String = "",
	cost: int = 0,
	type: CardType = CardType.CREATURE,
	power: int = 0,
	text_box: String = ""
) -> void:
	self.cardName = cardName
	self.cost = cost
	self.type = type
	self.power = power
	self.text_box = text_box
	
func describe() -> String:
	return "Card(name: %s, cost: %d, type: %s, power: %d, text: %s)" % [
		cardName,
		cost,
		CardType.keys()[type],
		power,
		text_box
	]
	
func getTypeAsString() -> String:
	match type:
		CardType.CREATURE: return "Creature"
		CardType.SPELL: return "Spell"
		CardType.PERMANENT: return "Permanent"
	return "TYPE"
