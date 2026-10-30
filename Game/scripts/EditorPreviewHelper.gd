@tool
extends Node
class_name EditorPreviewHelper

## Editor-only helper: lets you preview the wide/focused combat-zone layout directly in the
## editor viewport by reusing GameView's real runtime positioning logic (setup() +
## set_battlefield_focus()). Has no effect during actual gameplay - only runs as a @tool script.

enum FocusedLocation { LEFT, MIDDLE, RIGHT, GLOBAL }

@export var focused_location: FocusedLocation = FocusedLocation.GLOBAL:
	set(value):
		focused_location = value
		_apply_focus()

var _game_view: GameView = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_game_view = get_parent() as GameView
	if not _game_view:
		push_warning("EditorPreviewHelper: parent must be the GameView node")
		return
	_game_view.setup(true)  # headless: skip Card-view creation, we only need combat_zones positions
	_apply_focus()

func _apply_focus() -> void:
	if not Engine.is_editor_hint() or not _game_view:
		return
	_game_view.set_battlefield_focus(_index_for(focused_location))

func _index_for(location: FocusedLocation) -> int:
	match location:
		FocusedLocation.LEFT: return 0
		FocusedLocation.MIDDLE: return 1
		FocusedLocation.RIGHT: return 2
		_: return -1
