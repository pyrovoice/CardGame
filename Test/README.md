# CardGame Testing Framework

This directory contains the testing infrastructure for the card game project.

## Testing Approaches

### 1. Unit Tests (Fast, Logic-Only)
- **GameTestEnvironment.gd**: Lightweight game state simulation
- **TestCard.gd**: Mock Card implementation without 3D dependencies  
- **CardInteractionTest.gd**: Tests for card abilities and interactions

**Usage:**
```gdscript
# In Godot editor, run:
var test_runner = TestRunner.new()
```

### 2. Integration Tests (Slower, Full Scene)
- **GameSceneTest.gd**: Tests the actual 3D game scene
- Tests complete game flow including UI and 3D interactions

**Usage:**
```bash
# From command line:
godot --headless --script res://Test/GameSceneTest.gd
```

### 3. Mixed Approach (Recommended)
1. Use unit tests for card logic, abilities, and interactions
2. Use integration tests for game flow and UI interactions
3. Run unit tests frequently during development
4. Run integration tests before releases

## Example Test Cases

### Card Ability Tests
```gdscript
func test_goblin_matron_creates_token():
    var game = GameTestEnvironment.new()
    
    # Setup: Matron on battlefield, Goblin in hand
    var matron = game.create_test_card("Goblin Matron")
    game.player_base.append(matron)
    
    var goblin = game.create_test_card("Goblin Warchief")
    game.player_hand.append(goblin)
    
    # Action: Play the Goblin
    game.play_card_from_hand("Goblin Warchief")
    
    # Assert: Token was created
    assert(game.assert_token_created("Goblin"))
    assert(game.assert_ability_triggered("Goblin Matron", "CardPlayed"))
```

### Game Flow Tests
```gdscript
func test_card_play_flow():
    # Load actual game scene
    var game = load("res://Game/scenes/game.tscn").instantiate()
    
    # Test playing a card
    var initial_hand_size = game.player_hand.get_child_count()
    var card = game.player_hand.get_child(0)
    game.tryMoveCard(card, game.player_base)
    
    # Verify card moved
    assert(game.player_hand.get_child_count() == initial_hand_size - 1)
```

## Running Tests

### In Editor
1. Open Godot editor
2. In the FileSystem dock, right-click on `Test/TestRunner.gd`
3. Select "Change Script" and click the "Run" button
4. Check output in the debugger

### Command Line
```bash
# Unit tests
godot --headless --script res://Test/TestRunner.gd

# Integration tests  
godot --headless --script res://Test/GameSceneTest.gd

# Specific test
godot --headless --script res://Test/CardInteractionTest.gd
```

### CI/CD Integration
Add to your CI pipeline:
```yaml
- name: Run Game Tests
  run: |
    godot --headless --script res://Test/TestRunner.gd
    godot --headless --script res://Test/GameSceneTest.gd
```

## Adding New Tests

### For Card Logic (Recommended)
1. Add test methods to `CardInteractionTest.gd`
2. Use `GameTestEnvironment` for setup
3. Test specific card interactions and abilities

### For Game Flow
1. Add test methods to `GameSceneTest.gd`  
2. Load actual game scene
3. Test user interactions and game state changes

## Test Structure

```
Test/
├── README.md                 # This file
├── TestRunner.gd             # Main test runner
├── GameTestEnvironment.gd    # Mock game state for unit tests
├── TestCard.gd               # Mock Card class
├── CardInteractionTest.gd    # Card ability and interaction tests
├── GameSceneTest.gd          # Full scene integration tests
└── CardLoaderTest.gd         # Existing card loading tests
```

## Benefits

- **Fast Feedback**: Unit tests run in milliseconds
- **Comprehensive Coverage**: Test both logic and integration
- **Automated**: Can run in CI/CD without human intervention
- **Regression Prevention**: Catch when changes break existing functionality
- **Documentation**: Tests serve as examples of how the game should work

## Legacy Files

### CardLoaderTest.gd
A simple executable unit test script for testing the card loading system.

### TestRunner.gd (Updated)
A test runner that executes all unit tests in the project, now including the new card interaction tests.
