extends RefCounted
class_name LieutenantData

## Tracks per-Lieutenant refill counters for future card mechanics.

var role: String  # "aggro", "control", or "combo"
var deck_zone: GameZone.e
var hand_zone: GameZone.e
var gold: SignalInt  # This Lieutenant's own spending budget for the turn
var total_refills: int = 0
var refills_since_reset: int = 0  # Since combat started or this Lieutenant's location was last conquered

func _init(p_role: String, p_deck_zone: GameZone.e, p_hand_zone: GameZone.e):
	role = p_role
	deck_zone = p_deck_zone
	hand_zone = p_hand_zone
	gold = SignalInt.new(0)

func record_refill() -> void:
	total_refills += 1
	refills_since_reset += 1

func reset_since_last_conquest() -> void:
	refills_since_reset = 0
