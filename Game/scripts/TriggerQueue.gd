class_name TriggerQueue extends RefCounted

## Queue system for managing triggered abilities
## When events happen, abilities are added to this queue and resolved in order

class QueuedTrigger:
	var source_card_data: CardData  # The card whose ability triggered
	var ability  # The ability that triggered (CardAbility or Dictionary for backward compatibility)
	var trigger_context: Dictionary  # Context data about the trigger (what card died, etc.)
	
	func _init(p_source: CardData, p_ability, p_context: Dictionary = {}):
		source_card_data = p_source
		ability = p_ability
		trigger_context = p_context

var queue: Array[QueuedTrigger] = []

func add_trigger(source_card_data: CardData, ability, context: Dictionary = {}):
	"""Add a triggered ability to the queue (accepts CardAbility or Dictionary)"""
	var trigger = QueuedTrigger.new(source_card_data, ability, context)
	queue.append(trigger)
	
	var ability_desc = ""
	if ability is TriggeredAbility:
		ability_desc = TriggeredAbility.event_to_string(ability.game_event_trigger) + " -> " + EffectType.type_to_string(ability.effect_type)
	elif ability is Dictionary:
		ability_desc = ability.get("effect_type", "Unknown")
	
	print("📋 [TRIGGER QUEUE] Added: ", source_card_data.cardName, " - ", ability_desc)

func has_triggers() -> bool:
	"""Check if there are any triggers waiting to resolve"""
	return queue.size() > 0

func get_next_trigger() -> QueuedTrigger:
	"""Get the next trigger from the queue (FIFO)"""
	if queue.is_empty():
		return null
	return queue.pop_front()

func clear():
	"""Clear all triggers from the queue"""
	queue.clear()

func size() -> int:
	"""Get the number of triggers in the queue"""
	return queue.size()

func get_all_triggers() -> Array[QueuedTrigger]:
	"""Get all triggers in the queue (for inspection/debugging)"""
	return queue.duplicate()
