extends Control
class_name MainMenu

@onready var play_game_button: Button = $VBoxContainer/PlayGameButton
@onready var card_album_button: Button = $VBoxContainer/CardAlbumButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	# Connect button signals
	play_game_button.pressed.connect(_on_play_game_pressed)
	card_album_button.pressed.connect(_on_card_album_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_game_pressed():
	get_tree().change_scene_to_file("res://Game/scenes/game.tscn")

func _on_card_album_pressed():
	get_tree().change_scene_to_file("res://CardAlbum/scenes/CardAlbum.tscn")

func _on_quit_pressed():
	get_tree().quit()
