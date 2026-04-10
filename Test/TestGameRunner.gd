extends Node
class_name TestGameRunner

var current_test_manager: BaseTestManager  # The active test manager
var game_instance: Game = null
const GAME_VIEW: PackedScene = preload("uid://diasc2vlc4hu1")

# UI References (from scene)
@onready var suite_selector: Panel = $SuiteSelector
@onready var suite_title: Label = $SuiteSelector/VBox/Title
@onready var controller_button: Button = $SuiteSelector/VBox/ControllerButton
@onready var view_button: Button = $SuiteSelector/VBox/ViewButton
@onready var both_button: Button = $SuiteSelector/VBox/BothButton

# Test UI (shared by both test managers)
@onready var test_ui_panel: Panel = $TestUI
@onready var run_all_button: Button = $TestUI/RunAll
@onready var run_failed_button: Button = $TestUI/RunFailed
@onready var run_until_fail_button: Button = $TestUI/RunUntilFail
@onready var back_button: Button = $TestUI/Back
@onready var test_grid: GridContainer = $TestUI/TestGrid

func _ready():
	print("=== Starting Test Runner ===")
	
	# Connect suite selector buttons
	controller_button.pressed.connect(_on_controller_selected)
	view_button.pressed.connect(_on_view_selected)
	both_button.pressed.connect(_on_both_selected)
	
	# Connect test UI buttons
	run_all_button.pressed.connect(_on_run_all)
	run_failed_button.pressed.connect(_on_run_failed)
	run_until_fail_button.pressed.connect(_on_run_until_fail)
	back_button.pressed.connect(_on_back)
	
	# Start with suite selector visible
	_show_suite_selector()
	
	print("Test runner ready - choose which test suite to run")

func _show_suite_selector():
	"""Show the suite selection menu"""
	suite_selector.visible = true
	test_ui_panel.visible = false
	if current_test_manager:
		current_test_manager.queue_free()
		current_test_manager = null

func _show_test_ui(manager: BaseTestManager):
	"""Show the test UI with the given test manager"""
	suite_selector.visible = false
	test_ui_panel.visible = true
	current_test_manager = manager
	
	# Connect manager to UI elements
	manager.test_runner = self
	manager.run_all_button = run_all_button
	manager.run_failed_button = run_failed_button
	manager.failed_tests_2 = run_until_fail_button
	manager.test_grid_container = test_grid
	
	# Populate test buttons
	_populate_test_buttons()

func _populate_test_buttons():
	"""Create buttons for each test in the current manager"""
	# Clear existing buttons
	for child in test_grid.get_children():
		child.queue_free()
	await get_tree().process_frame
	
	var test_methods = current_test_manager._discover_test_methods()
	
	for test_method in test_methods:
		var button = Button.new()
		button.name = test_method
		button.text = test_method.replace("test_", "").replace("_", " ").capitalize()
		button.pressed.connect(_on_individual_test.bind(test_method))
		test_grid.add_child(button)
		
		# Apply initial color based on session results
		_update_button_appearance(button, test_method)

func _update_button_appearance(button: Button, test_method: String):
	"""Update button color based on test result"""
	if test_method in current_test_manager.session_test_results:
		var result = current_test_manager.session_test_results[test_method]
		if result.passed:
			button.modulate = Color.GREEN
		else:
			button.modulate = Color.RED
	else:
		button.modulate = Color.WHITE

func _update_all_buttons():
	"""Update all test button appearances"""
	for child in test_grid.get_children():
		if child is Button:
			_update_button_appearance(child, child.name)

# === BUTTON HANDLERS ===

func _on_controller_selected():
	"""User selected controller tests"""
	CardAnimator.ANIMATION_SPEED = 10.0
	print("🏃 Controller tests: Set animation speed to 10x")
	
	var manager = ControllerTestManager.new()
	_show_test_ui(manager)

func _on_view_selected():
	"""User selected view tests"""
	CardAnimator.ANIMATION_SPEED = 10.0
	print("🎨 View tests: Set animation speed to 10x")
	
	var manager = ViewTestManager.new()
	_show_test_ui(manager)

func _on_both_selected():
	"""Run both test suites sequentially"""
	suite_selector.visible = false
	await _run_both_test_suites()
	_show_suite_selector()

func _on_run_all():
	"""Run all tests in current manager"""
	await current_test_manager.runTests()
	_update_all_buttons()
	_restore_animation_speed()
	cleanup_game()
	await get_tree().process_frame

func _on_run_failed():
	"""Run only failed tests"""
	await current_test_manager.runFailedTests()
	_update_all_buttons()
	_restore_animation_speed()
	cleanup_game()
	await get_tree().process_frame

func _on_run_until_fail():
	"""Run tests until first failure"""
	await current_test_manager.runTestsUntilFailure()
	_update_all_buttons()
	_restore_animation_speed()
	cleanup_game()
	await get_tree().process_frame

func _on_individual_test(test_method: String):
	"""Run a single test"""
	var is_headless = current_test_manager.is_headless_mode()
	var mode_str = "headless" if is_headless else "with animations"
	print("=== Running Individual Test: ", test_method, " (", mode_str, ") ===")
	
	var result = await current_test_manager._run_single_test(test_method, is_headless)
	
	# Update session results
	current_test_manager.session_test_results[test_method] = result
	
	# Update button appearance
	var button = test_grid.get_node(test_method)
	_update_button_appearance(button, test_method)
	
	# Print result
	if result.passed:
		print("✅ PASSED: ", test_method, " (", result.duration_ms, "ms)")
	else:
		print("❌ FAILED: ", test_method, " - ", result.error)
	
	cleanup_game()
	await get_tree().process_frame

func _on_back():
	"""Return to suite selector"""
	_restore_animation_speed()
	_show_suite_selector()

func _restore_animation_speed():
	"""Restore normal animation speed"""
	CardAnimator.ANIMATION_SPEED = 1.0
	print("🐌 Restored animation speed to normal (1.0x)")

# === SUITE MANAGEMENT ===

func _run_both_test_suites():
	"""Run both test suites and display aggregated results"""
	print("\n" + "=".repeat(60))
	print("=== Running Both Test Suites ===")
	print("=".repeat(60) + "\n")
	
	CardAnimator.ANIMATION_SPEED = 10.0
	var total_passed = 0
	var total_failed = 0
	
	# Run controller tests
	print("\n--- Starting Controller Test Suite (Headless) ---")
	var controller_manager = ControllerTestManager.new()
	controller_manager.test_runner = self
	
	var controller_results = await controller_manager.runTests()
	total_passed += controller_results.passed
	total_failed += controller_results.failed
	
	controller_manager.queue_free()
	cleanup_game()
	await get_tree().process_frame
	
	# Run view tests
	print("\n--- Starting View Test Suite (With Animations) ---")
	var view_manager = ViewTestManager.new()
	view_manager.test_runner = self
	
	var view_results = await view_manager.runTests()
	total_passed += view_results.passed
	total_failed += view_results.failed
	
	view_manager.queue_free()
	cleanup_game()
	await get_tree().process_frame
	
	# Print aggregated results
	print("\n" + "=".repeat(60))
	print("=== Combined Test Results ===")
	print("Controller Tests: ", controller_results.passed, " passed, ", controller_results.failed, " failed")
	print("View Tests: ", view_results.passed, " passed, ", view_results.failed, " failed")
	print("---")
	print("TOTAL: ", total_passed, " passed, ", total_failed, " failed")
	print("=".repeat(60) + "\n")
	
	_restore_animation_speed()

func ensure_game_loaded():
	"""Load the game controller if it hasn't been loaded yet and return it"""
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
	
	return game_instance

func show_test_manager():
	"""Called by test managers when they complete - no longer needed with new architecture"""
	pass  # Kept for compatibility

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
