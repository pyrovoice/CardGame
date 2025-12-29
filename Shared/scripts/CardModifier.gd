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
	
	# Add the keyword to the card's abilities
	var keyword_ability = {
		"type": "KeywordAbility",
		"keyword": keyword,
		"duration": duration,
		"granted_by": "Modification"
	}
	target_card.cardData.abilities.append(keyword_ability)
	
	# Track for removal if not permanent
	_track_modification_for_removal(target_card, "keyword", {"keyword": keyword}, duration)

static func _apply_type_modification(target_card: Card, type_string: String, duration: String):
	"""Internal: Apply type modification to a card"""
	if type_string.is_empty():
		print("❌ No type specified for modification")
		return
	
	if CardData.isValidCardTypeString(type_string):
		var card_type = CardData.stringToCardType(type_string)
		target_card.cardData.addType(card_type)
		print("  ✨ Added type ", type_string, " to ", target_card.cardData.cardName)
		
		# Track for removal if not permanent
		_track_modification_for_removal(target_card, "type", {"type_to_remove": type_string}, duration)
	else:
		print("❌ Invalid card type: ", type_string)

static func _apply_subtype_modification(target_card: Card, subtype: String, duration: String):
	"""Internal: Apply subtype modification to a card"""
	if subtype.is_empty():
		print("❌ No subtype specified for modification")
		return
	
	target_card.cardData.addSubtype(subtype)
	print("  ✨ Added subtype ", subtype, " to ", target_card.cardData.cardName)
	
	# Track for removal if not permanent
	_track_modification_for_removal(target_card, "type", {"type_to_remove": subtype}, duration)

static func _apply_power_modification(target_card: Card, amount: int, duration: String, is_boost: bool):
	"""Internal: Apply power modification to a card (boost or reduction)"""
	if amount == 0:
		print("⚠️ Power modification amount is 0")
		return
	
	var actual_amount = amount if is_boost else -amount
	var old_power = target_card.cardData.power
	target_card.cardData.power += actual_amount
	
	var symbol = "+" if is_boost else "-"
	print("  💪 Modifying ", target_card.cardData.cardName, " power: ", old_power, " → ", target_card.cardData.power, " (", symbol, amount, ")")
	
	# Track for removal if not permanent
	_track_modification_for_removal(target_card, "power_boost", {"power_bonus": actual_amount}, duration)

static func _track_modification_for_removal(target_card: Card, effect_type: String, effect_data: Dictionary, duration: String):
	"""Internal: Track a modification for later removal based on duration"""
	match duration:
		"Permanent":
			# Nothing to track - modification is permanent
			pass
		"EndOfTurn", "WhileSourceInPlay":
			# Create effect entry with duration
			var effect_entry = effect_data.duplicate()
			effect_entry["type"] = effect_type
			effect_entry["duration"] = duration
			
			target_card.cardData.add_temporary_effect(effect_entry)
			print("  ⏰ Scheduled removal at ", duration, " (", target_card.cardData.temporary_effects.size(), " effects tracked)")
		_:
			print("❌ Unsupported duration: ", duration)
