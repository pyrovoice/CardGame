extends Node
class_name TestGameRunner

var game_scene: PackedScene = preload("res://Game/scenes/game.tscn")
var test_manager_scene: PackedScene = preload("res://Test/TestManager.tscn")
var test_manager: TestManager

func _ready():
	print("=== Starting Test Manager ===")
	
	# Load and setup test manager UI first
	test_manager = test_manager_scene.instantiate()
	test_manager.test_runner = self  # Give test manager reference to runner
	add_child(test_manager)
	
	print("TestManager UI loaded and ready")
	print("Use the buttons to run tests!")

func ensure_game_loaded() -> Game:
	"""Load the game if it hasn't been loaded yet and return it"""
	var game_instance = get_node_or_null("Game")
	if not game_instance:
		print("Loading game for test execution...")
		game_instance = game_scene.instantiate()
		game_instance.name = "Game"
		game_instance.doStartGame = false
		add_child(game_instance)
		
		# Hide the test manager UI while tests are running
		test_manager.visible = false
		print("Game loaded, UI hidden for test execution")
	
	return game_instance

func show_test_manager():
	"""Show the test manager UI after tests complete"""
	if test_manager:
		test_manager.visible = true
		print("Test execution complete, UI restored")

func cleanup_game():
	"""Destroy the game instance to reset state"""
	var game_instance = get_node_or_null("Game")
	if game_instance:
		print("Cleaning up game instance...")
		game_instance.queue_free()
		print("Game instance destroyed - state reset to initial")
