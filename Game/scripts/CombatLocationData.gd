extends RefCounted
class_name CombatLocationData

var relatedLocation: CombatZone
var player_capture_threshold = SignalInt.new(10)
var player_capture_current = SignalInt.new(0)
var opponent_capture_threshold = SignalInt.new(10)
var opponent_capture_current = SignalInt.new(0)
var isCombatResolved: SignalBool = SignalBool.new(false)

func _init(combatZone: CombatZone):
	if !combatZone:
		return
	relatedLocation = combatZone
	combatZone.location_fill_player.setup_capture_bar(player_capture_current, player_capture_threshold)
	combatZone.location_fill_opponent.setup_capture_bar(opponent_capture_current, opponent_capture_threshold)
	isCombatResolved.value_changed.connect(relatedLocation.update_resolve_fight_display)
