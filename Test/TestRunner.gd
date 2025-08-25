@tool
extends RefCounted
class_name TestRunner

# Simple test runner for the card game project
# Run this to execute all unit tests

static func run_all_tests():
	print("=== Test Runner Starting ===")
	print("Running all unit tests for CardGame project...")
	
	# Load and run CardLoaderTest
	var card_test_script = load("res://Test/CardLoaderTest.gd")
	if card_test_script:
		card_test_script.run_tests()
	else:
		print("Failed to load CardLoaderTest")
	
	print("\n=== All Tests Complete ===")

# Entry point
func _init():
	run_all_tests()
