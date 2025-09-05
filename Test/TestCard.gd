extends RefCounted
class_name TestCard

# Lightweight Card implementation for testing
# Mimics the essential functionality of Card without 3D scene dependencies

var cardData: CardData
var objectID: String = ""
var damage: int = 0
var current_zone: String = "hand"  # Track which zone this card is in

func _init():
	pass

func getPower() -> int:
	if cardData:
		return cardData.power
	return 0

func getToughness() -> int:
	if cardData:
		return cardData.toughness  
	return 0

func getDamage() -> int:
	return damage

func receiveDamage(amount: int):
	damage += amount

func getManaCost() -> int:
	if cardData:
		return cardData.manaCost
	return 0

func getCardName() -> String:
	if cardData:
		return cardData.cardName
	return ""

func getSubtypes() -> Array[String]:
	if cardData and cardData.subtypes:
		return cardData.subtypes
	return []

func hasSubtype(subtype: String) -> bool:
	return subtype in getSubtypes()

func isCreature() -> bool:
	if cardData:
		return cardData.type == CardData.CardType.CREATURE
	return false

func set_current_zone(zone: String):
	current_zone = zone

func get_current_zone() -> String:
	return current_zone

# Mock functions that don't need implementation for testing
func animatePlayedTo(_position: Vector3):
	pass

func setRotation(_rotation: Vector3, _duration: float):
	pass

func makeSmall():
	pass

func updateDisplay():
	pass

# Note: Removed reparent() and get_parent() methods as they conflict with Node methods
# For testing, we handle parent relationships differently in GameTestEnvironment
