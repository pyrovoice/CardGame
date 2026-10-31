extends Resource
class_name PlayerControlLock

## Emitted when the last lock is released, i.e. the player can act again.
signal control_regained

var locks = []

func addLock() -> Lock:
	var lock = Lock.new()
	locks.push_back(lock)
	return lock

func removeLock(lock: Lock):
	var index = locks.find(lock)
	if index == -1:
		return
	locks.remove_at(index)
	if locks.is_empty():
		control_regained.emit()

func isLocked() -> bool:
	return locks.size() > 0
	
class Lock:
	static var counter = 0
	var uuid: int
	
	func init():
		uuid = counter
		counter +=1
		
