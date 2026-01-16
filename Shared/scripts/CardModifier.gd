extends Node
class_name CardModifier

## Utility class for modifying cards (keywords, types, power, etc.)
## This centralizes all card modification logic

static func modify_card(target_card: Card, modification_type: String, modification_data: Dictionary, duration: String):
	"""
	Unified method to apply any modification to a card (keyword, type, power boost, etc.)
	
	Parameters:
	- target_card: The card to modify
	- modification_type: Type of modification ("keyword", "type", "subtype", "power_boost", "power_reduction")
	- modification_data: Dictionary containing modification details:
		- For "keyword": {"keyword": "Spellshield"}
		- For "type": {"type": "Creature"}
		- For "subtype": {"subtype": "Goblin"}
		- For "power_boost": {"amount": 3}
		- For "power_reduction": {"amount": 2}
	- duration: "Permanent", "EndOfTurn", or "WhileSourceInPlay"
	"""
	match modification_type:
		"keyword":
			_apply_keyword_modification(target_card, modification_data.get("keyword", ""), duration)
		
		"type":
			_apply_type_modification(target_card, modification_data.get("type", ""), duration)
		
		"subtype":
			_apply_subtype_modification(target_card, modification_data.get("subtype", ""), duration)
		
		"power_boost":
			_apply_power_modification(target_card, modification_data.get("amount", 0), duration, true)
		
		"power_reduction":
			_apply_power_modification(target_card, modification_data.get("amount", 0), duration, false)
		
		_:
			print("❌ Unknown modification type: ", modification_type)
			return
	
	# Update the card's visual display after any modification
	if target_card.has_method("updateDisplay"):
		target_card.updateDisplay()
	
	# Emit dirty signal to update UI
	target_card.cardData.emit_signal("dirty_data")

static func _apply_keyword_modification(target_card: Card, keyword: String, duration: String):
	"""Internal: Apply keyword modification to a card"""
	if keyword.is_empty():
		print("❌ No keyword specified for modification")
		return
	
	print("  ✨ Granting ", keyword, " to ", target_card.cardData.cardName)
	
	# Track the temporary effect (will be checked dynamically when querying keywords)
	var duration_enum = _string_to_duration_enum(duration)
	var temp_effect = TemporaryEffect.create_keyword_effect(keyword, duration_enum, target_card.cardData)
	target_card.cardData.add_temporary_effect(temp_effect)
	target_card.cardData.dirty_data.emit()

static func _apply_type_modification(target_card: Card, type_string: String, duration: String):
	"""Internal: Apply type modification to a card"""
	if type_string.is_empty():
		print("❌ No type specified for modification")
		return
	
	if CardData.isValidCardTypeString(type_string):
		print("  ✨ Added type ", type_string, " to ", target_card.cardData.cardName)
		
		# Track the temporary effect (will be checked dynamically when querying types)
		var duration_enum = _string_to_duration_enum(duration)
		var temp_effect = TemporaryEffect.create_type_effect(type_string, false, duration_enum, target_card.cardData)
		target_card.cardData.add_temporary_effect(temp_effect)
		target_card.cardData.dirty_data.emit()
	else:
		print("❌ Invalid card type: ", type_string)

static func _apply_subtype_modification(target_card: Card, subtype: String, duration: String):
	"""Internal: Apply subtype modification to a card"""
	if subtype.is_empty():
		print("❌ No subtype specified for modification")
		return
	
	print("  ✨ Added subtype ", subtype, " to ", target_card.cardData.cardName)
	
	# Track the temporary effect (will be checked dynamically when querying subtypes)
	var duration_enum = _string_to_duration_enum(duration)
	var temp_effect = TemporaryEffect.create_type_effect(subtype, true, duration_enum, target_card.cardData)
	target_card.cardData.add_temporary_effect(temp_effect)
	target_card.cardData.dirty_data.emit()

static func _apply_power_modification(target_card: Card, amount: int, duration: String, is_boost: bool):
	"""Internal: Apply power modification to a card (boost or reduction)"""
	if amount == 0:
		print("⚠️ Power modification amount is 0")
		return
	
	var actual_amount = amount if is_boost else -amount
	var symbol = "+" if is_boost else "-"
	print("  💪 Modifying ", target_card.cardData.cardName, " power: (", symbol, amount, ")")
	
	# Track the temporary effect (will be calculated dynamically when querying power)
	var duration_enum = _string_to_duration_enum(duration)
	var temp_effect = TemporaryEffect.create_power_boost_effect(actual_amount, duration_enum, target_card.cardData)
	target_card.cardData.add_temporary_effect(temp_effect)
	target_card.cardData.dirty_data.emit()

static func _string_to_duration_enum(duration_str: String) -> TemporaryEffect.Duration:
	"""Convert string to duration enum"""
	match duration_str:
		"EndOfTurn":
			return TemporaryEffect.Duration.END_OF_TURN
		"EndOfCombat":
			return TemporaryEffect.Duration.END_OF_COMBAT
		"Permanent":
			return TemporaryEffect.Duration.PERMANENT
		"WhileSourceInPlay":
			return TemporaryEffect.Duration.CUSTOM
		_:
			return TemporaryEffect.Duration.END_OF_TURN
