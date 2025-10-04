extends Node
class_name TestGameRunner

var game_scene: PackedScene = preload("res://Game/scenes/game.tscn")
var game_instance: Game
var test_manager: TestManager

func _ready():
	print("=== Starting Test Game Runner ===")
	
	# Load the game scene
	game_instance = game_scene.instantiate()
	game_instance.doStartGame = false
	add_child(game_instance)
	print("Game loaded and ready")
	
	# Create and setup test manager
	test_manager = TestManager.new()
	test_manager.game = game_instance
	add_child(test_manager)
	
	print("TestManager created, waiting for game to stabilize...")
	
	print("Starting tests...")
	
	# Run the tests
	var results = await test_manager.runTests()
	
	print("\n=== Test Session Complete ===")
	print("Results: ", results.passed, " passed, ", results.failed, " failed")
	
	# Optional: Return to main menu after tests
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://MainMenu/scenes/MainMenu.tscn")
