extends Node
class_name TestGameRunner

var test_manager_scene: PackedScene = preload("res://Test/TestManager.tscn")
var test_manager: TestManager
var game_instance: Game = null  # Store the game controller reference
const GAME_VIEW: PackedScene = preload("uid://diasc2vlc4hu1")

func _ready():
	print("=== Starting Test Manager ===")
	
	# Load and setup test manager UI first
	test_manager = test_manager_scene.instantiate()
	test_manager.test_runner = self  # Give test manager reference to runner
	add_child(test_manager)
	
	print("TestManager UI loaded and ready")
	print("Use the buttons to run tests!")

func ensure_game_loaded():
	"""Load the game controller if it hasn't been loaded yet and return it
	
	Returns the Game controller node. GameView is accessible via game.game_view.
	"""
	if not game_instance:
		print("Loading game for test execution...")
		var game = GAME_VIEW.instantiate()
		game.doStartGame = false
		game_instance = game
		add_child(game_instance)
		
		await get_tree().process_frame
		
		if not game_instance.is_node_ready():
			await game_instance.ready
		
		print("🎮 Game controller fully initialized with GameView")
		
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
	if game_instance:
		print("Cleaning up game instance...")
		# Clear the CardPaymentManager's game reference before destroying
		CardPaymentManagerAL.set_game_context(null)
		game_instance.queue_free()
		game_instance = null  # Clear the stored reference
		# Wait a frame to ensure complete cleanup
		await get_tree().process_frame
		print("Game instance destroyed - state reset to initial")
