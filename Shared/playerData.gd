extends Node
class_name PlayerData

const SAVE_PATH = "user://player_data.json"

# Archetype IDs that the player has unlocked.
# Each ID matches the stem of a file in DeckData/ (e.g. "punglynd" → DeckData/Punglynd.json).
var unlocked_archetypes: Array[String] = []

func _ready() -> void:
	load_data()

# ---------------------------------------------------------------------------
# Archetype access
# ---------------------------------------------------------------------------

func unlock_archetype(archetype_id: String) -> void:
	if archetype_id not in unlocked_archetypes:
		unlocked_archetypes.append(archetype_id)
		save_data()

func is_archetype_unlocked(archetype_id: String) -> bool:
	return archetype_id in unlocked_archetypes

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func save_data() -> void:
	var data := {
		"unlocked_archetypes": unlocked_archetypes,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("PlayerData: could not open save file for writing: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_defaults()
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("PlayerData: could not open save file for reading: " + SAVE_PATH)
		_apply_defaults()
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("PlayerData: JSON parse error: " + json.get_error_message())
		_apply_defaults()
		return

	var data: Dictionary = json.get_data()
	unlocked_archetypes.clear()
	for id in data.get("unlocked_archetypes", []):
		unlocked_archetypes.append(str(id))

func _apply_defaults() -> void:
	unlocked_archetypes = ["punglynd"]
