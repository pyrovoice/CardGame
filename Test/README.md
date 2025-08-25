# Test Directory

This directory contains unit tests for the CardGame project.

## Files

### CardLoaderTest.gd
A simple executable unit test script for testing the card loading system.

**Features:**
- Tests loading all cards from the Cards directory using CardLoader
- Tests parsing cards from text variables (no test files needed)
- Tests string-to-integer conversion for card properties
- Tests subtype parsing including multiple subtypes
- Validates card data parsing and CardData object creation
- Uses CardLoader class for all card loading functionality

**Usage:**
1. **In Godot Editor:** Open the script and click "Run" or press F6
2. **From Script:** Call `CardLoaderTest.run_tests()` in any other script
3. **Command Line:** Use Godot's headless mode to run tests

### TestRunner.gd
A test runner that executes all unit tests in the project.

**Usage:**
1. **In Godot Editor:** Open the script and click "Run" or press F6
2. **From Script:** Call `TestRunner.run_all_tests()`

## Running Tests

### Method 1: Direct Execution
1. Open `CardLoaderTest.gd` in the Godot script editor
2. Click the "Run" button or press F6
3. View results in the output console

### Method 2: Via TestRunner
1. Open `TestRunner.gd` in the Godot script editor
2. Click the "Run" button or press F6
3. This will run all tests in the project

### Method 3: From Code
```gdscript
# In any other script
CardLoaderTest.run_tests()
# or
TestRunner.run_all_tests()
```

## Test Coverage

The current tests cover:
- ✅ Loading cards from text files using CardLoader
- ✅ Parsing card data from text variables (no test files needed)
- ✅ Parsing card properties (Name, ManaCost, Power, Types, CardText)
- ✅ String-to-integer conversion using `int()`
- ✅ Type and subtype parsing (main type + up to 3 subtypes)
- ✅ CardData object creation and validation
- ✅ Directory scanning for all card files

## Adding New Tests

To add new tests:
1. Create a new test script in this directory
2. Extend `RefCounted` and use `@tool` annotation
3. Create static test functions
4. Add the test to `TestRunner.gd`

Example:
```gdscript
@tool
extends RefCounted
class_name MyNewTest

static func run_tests():
    print("=== My New Test ===")
    # Your test code here
    print("✓ Test passed")
```
