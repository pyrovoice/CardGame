# Card Loading System

This system allows you to create Card game objects from text file descriptions in Godot 4+.

## How it Works

### 1. Card Text Files
Cards are defined in `.txt` files in the `Cards/` directory. Each file contains key-value pairs:

```
Name:Goblin pair
ManaCost:1
Types:Creature Goblin
Power:1
CardText:When CARDNAME enters, create a 1 power Goblin creature token at the same location.
```

**Type System:**
- **Main Type:** First word in `Types` field (Creature, Spell, Permanent)
- **Subtypes:** Remaining words (up to 3) - e.g., Goblin, Warrior, Fire
- Example: `Types:Creature Goblin Warrior Fire` creates a Creature with subtypes [Goblin, Warrior, Fire]

### 2. CardLoader System
The `CardLoader` class is the central place for all card loading functionality:
- `parse_card_data(card_text)` - Parse card data from text content (file or string)
- `load_card_from_file(file_path)` - Load a single card from a text file
- `load_all_cards()` - Load all cards from the Cards directory
- `load_card_by_name(card_name)` - Load a specific card by name

The game script uses CardLoader for all card loading operations and maintains a library of loaded cards.

### 3. Integration with Game
- Cards are loaded automatically when the game starts (`_ready()` function)
- The `drawCard()` function now creates cards from the loaded library instead of a deck
- You can press 'T' in game to test creating specific cards

### 4. String to Integer Conversion and Subtype Parsing
As requested, the system uses Godot 4's `int()` function to convert string values and parses subtypes:
```gdscript
if "ManaCost" in properties:
    card_data.cost = int(properties["ManaCost"])  # Converts "1" to 1

if "Types" in properties:
    var types_text = properties["Types"]
    var type_parts = types_text.split(" ")
    
    # First part is main type (Creature, Spell, Permanent)
    # Remaining parts are subtypes (up to 3)
    for i in range(1, min(type_parts.size(), 4)):
        card_data.subtypes.append(type_parts[i])
```

## Usage Examples

### Load a specific card:
```gdscript
var goblin_data = get_card_data_by_name("Goblin pair")
var goblin_card = create_card_from_data(goblin_data)
```

### Create random cards:
```gdscript
var random_data = get_random_card_data()
var random_card = create_card_from_data(random_data)
```

## Files Modified/Created:
- `Game/scripts/game.gd` - Added card loading system
- `Game/scripts/CardLoader.gd` - Standalone card loader class (optional)
- `Test/CardLoaderTest.gd` - Unit test script for card loading
- `Test/TestRunner.gd` - Test runner for all unit tests
- `Test/README.md` - Test documentation

## Testing:
1. **Run Unit Tests:** Open `Test/CardLoaderTest.gd` or `Test/TestRunner.gd` in Godot and press F6 (Run)
2. **In Game:** Run the game - cards will be loaded automatically and printed to console
3. **Manual Testing:** Press 'T' in game to create specific cards from text files

The unit tests will verify that the system successfully converts text descriptions like "ManaCost:1" into integer values (1) for the CardData objects.
