extends SceneTree

const RESULT_PREFIX := "CARDGAME_TEST_RESULT:"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "controller":
		push_error("Expected the controller suite and a test name or --list")
		quit(2)
		return

	# Load the scene after autoloads are initialized.
	var runner: Node = load("res://Test/TestGameRunner.tscn").instantiate()
	root.add_child(runner)
	runner._on_controller_selected()
	var manager = runner.current_test_manager
	var test_methods: Array[String] = manager._discover_test_methods()

	if args[1] == "--list":
		print(RESULT_PREFIX + JSON.stringify({"suite": args[0], "tests": test_methods}))
	elif args[1] not in test_methods:
		push_error("Unknown test: " + args[1])
		manager.free()
		runner.queue_free()
		quit(2)
		return
	else:
		var result: Dictionary = await manager._run_single_test(args[1], manager.is_headless_mode())
		await runner.cleanup_game()
		print(RESULT_PREFIX + JSON.stringify({"suite": args[0], "result": result}))

	manager.free()
	runner.queue_free()
	await process_frame
	quit()
