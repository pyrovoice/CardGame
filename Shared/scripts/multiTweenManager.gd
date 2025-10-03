extends Node
class_name MultiTweenManager

var tweens: Array[Tween] = []
signal all_completed
var finishedCounter = 0
static func createManager():
	return MultiTweenManager.new()

func addTween(t: Tween):
	tweens.push_back(t)
	t.finished.connect(func():
		finishedCounter += 1
		if finishedCounter == tweens.size():
			all_completed.emit()
		)
		

func waitComplete():
	while(finishedCounter < tweens.size()):
		await get_tree().create_timer(0.5).timeout
	queue_free()
