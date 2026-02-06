extends StaticBody3D
class_name CardContainer

# Common properties for all card containers
# Note: Card data tracking is now handled by GameData model
# CardContainer is purely a visual/positional reference
var is_hidden_for_owner = false
var is_hidden_for_opponent = true

# Zone identifier - links this container to a GameData zone
var zone_name: GameZone.e = GameZone.e.UNKNOWN

# Check if this container is hidden for a specific player
func is_hidden_for_player(is_owner: bool) -> bool:
	if is_owner:
		return is_hidden_for_owner
	else:
		return is_hidden_for_opponent
