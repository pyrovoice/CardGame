extends Resource
class_name PlayerControlLock

var locks = []

func addLock() -> Lock:
	var lock = Lock.new()
	locks.push_back(lock)
	return lock

func removeLock(lock: Lock):
	locks.remove_at(locks.find(lock))

func isLocked() -> bool:
	return locks.size() > 0
	
class Lock:
	static var counter = 0
	var uuid: int
	
	func init():
		uuid = counter
		counter +=1
		
