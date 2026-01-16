class_name ResolvableQueue extends RefCounted

## Queue system for managing resolvable abilities and effects
## When events happen, abilities are added to this queue and resolved in order

class QueuedResolvable:
	var source_card_data: CardData  # The card whose ability is resolving
	var ability  # The ability that is resolving (CardAbility or Dictionary for backward compatibility)
	
	func _init(p_source: CardData, p_ability):
		source_card_data = p_source
		ability = p_ability

var queue: Array[QueuedResolvable] = []

func add_resolvable(source_card_data: CardData, ability):
	var resolvable = QueuedResolvable.new(source_card_data, ability)
	queue.append(resolvable)

func has_resolvables() -> bool:
	return queue.size() > 0

func get_next_resolvable() -> QueuedResolvable:
	"""Get the next resolvable from the queue (FIFO)"""
	if queue.is_empty():
		return null
	return queue.pop_front()

func clear():
	"""Clear all resolvables from the queue"""
	queue.clear()

func size() -> int:
	"""Get the number of resolvables in the queue"""
	return queue.size()

func get_all_resolvables() -> Array[QueuedResolvable]:
	"""Get all resolvables in the queue (for inspection/debugging)"""
	return queue.duplicate()
