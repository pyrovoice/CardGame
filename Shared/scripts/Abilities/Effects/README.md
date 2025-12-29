# Ability Effects System

This folder contains the refactored ability effects system, which provides a clean, modular architecture for implementing card effects in the game.

## Architecture

### Separation of Concerns

The system is organized into distinct layers:
1. **Ability Level**: Handles targeting, replacement effects, and effect orchestration
2. **Effect Level**: Executes the actual effect logic on resolved targets

### Base Class
- **Effect.gd**: Abstract base class that all effect types extend
  - `execute()`: Main method to run the effect (must be implemented by subclasses)
  - `validate_parameters()`: Validates that required parameters are present
  - `get_description()`: Returns a human-readable description of the effect

**Important**: Effects should NOT handle target resolution or replacement effects internally. These are handled at the ability level before the effect executes.

### Effect Types

Each effect type is implemented as a separate class:

1. **DealDamageEffect.gd**: Deals damage to target creatures/players
   - Parameters: `NumDamage`, `Targets` (pre-resolved array)
   
2. **PumpEffect.gd**: Temporarily increases/decreases creature power
   - Parameters: `PowerBonus`, `Duration`, `Targets` (pre-resolved array)
   
3. **AddKeywordEffect.gd**: Grants keyword abilities to creatures (formerly PumpAll)
   - Parameters: `KW` (keyword), `Duration`, `Targets` (pre-resolved array)
   
4. **CreateTokenEffect.gd**: Creates token creatures
   - Parameters: `TokenScript`, `tokens_to_create` (modified by replacement effects at ability level)
   
5. **CastEffect.gd**: Plays/casts cards from any zone (deck, hand, graveyard)
   - Parameters: `Target` (e.g., "Self")
   - Supports casting from DECK, HAND (TODO), GRAVEYARD (TODO)
   
6. **DrawCardEffect.gd**: Draws cards for a player
   - Parameters: `NumCards`/`Amount`/`CardsDrawn`, `Defined` (player)
   
7. **AddTypeEffect.gd**: Adds types/subtypes to cards
   - Parameters: `Types`, `Duration`, `Targets` (pre-resolved array)

### Supporting Classes

- **EffectFactory.gd**: Factory class for creating Effect instances
  - `create_effect(effect_type: EffectType.Type)`: Creates appropriate Effect subclass
  - `execute_effect()`: Convenience method to create and execute in one call
  
- **TargetResolver.gd**: Resolves targets for effects at the ability level
  - `resolve_targets()`: Converts targeting parameters into actual Card objects
  - `find_valid_cards()`: Finds all cards matching a condition string
  - `is_valid_card_for_condition()`: Checks if a card matches targeting criteria
  - Handles: "Self", "All", "ValidCards", "ValidTargets", "Creature.YouCtrl", etc.
  
- **ReplacementEffectManager.gd**: Applies replacement effects before effect execution
  - `apply_replacement_effects()`: Modifies effect context based on active replacement effects
  - Checks conditions like ActiveZones, ValidToken, etc.
  - Handles: Token multiplication (Goblin Warchief), and other replacement effects
  
- **CardModifier.gd**: Utility class for modifying cards (keywords, types, power)
  - `modify_card()`: Unified method for all card modifications
  - Handles temporary effects with durations (Permanent, EndOfTurn, WhileSourceInPlay)
  - Tracks modifications for later removal

## Usage

### From AbilityManager

The AbilityManager orchestrates the full flow:
1. Resolve targets using TargetResolver
2. Apply replacement effects using ReplacementEffectManager (for applicable effects)
3. Execute effect using EffectFactory

```gdscript
# In executeAbilityEffect()
var effect_type_enum = EffectType.string_to_type(effect_type_str)

# Resolve targets at ability level
var resolved_parameters = effect_parameters.duplicate()
var targets = TargetResolver.resolve_targets(resolved_parameters, source_card_data, game_context)
resolved_parameters["Targets"] = targets

# Apply replacement effects if needed
if effect_type_enum == EffectType.Type.CREATE_TOKEN:
    var effect_context = ReplacementEffectManager.apply_replacement_effects(...)
    resolved_parameters["tokens_to_create"] = effect_context.get("tokens_to_create", 1)

# Execute the effect
await EffectFactory.execute_effect(effect_type_enum, resolved_parameters, source_card_data, game_context)
```

### Creating a New Effect Type

1. Create a new class extending `Effect` in this folder
2. Implement `execute()`, `validate_parameters()`, and `get_description()`
3. **Do NOT** handle target resolution or replacement effects in the effect class
4. Expect pre-resolved targets in `parameters["Targets"]`
5. Add a new enum value to `EffectType.gd`
6. Add a case to `EffectFactory.create_effect()` to instantiate your new class
7. (Optional) Add target resolution logic in AbilityManager if needed

Example:

```gdscript
extends Effect
class_name MyCustomEffect

func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
    # Get pre-resolved targets
    var targets: Array = parameters.get("Targets", [])
    
    if targets.is_empty():
        print("⚠️ No targets for custom effect")
        return
    
    # Apply effect to each target
    for target in targets:
        print("Applying custom effect to ", target.cardData.cardName)
        # Do effect logic here

func validate_parameters(parameters: Dictionary) -> bool:
    return true  # Or check for required params

func get_description(parameters: Dictionary) -> String:
    return "Does something cool to targets"
```

## Design Principles

### 1. Single Responsibility
- **Effects**: Execute the effect logic only
- **TargetResolver**: Find and filter target cards only
- **ReplacementEffectManager**: Modify effect parameters only
- **AbilityManager**: Orchestrate the full flow

### 2. Dependency Flow
```
AbilityManager (orchestration)
    ↓
TargetResolver (resolve targets)
    ↓
ReplacementEffectManager (modify effect)
    ↓
EffectFactory → Effect (execute)
```

### 3. Data Flow
```
Card Definition → Ability → AbilityManager
    → TargetResolver (produces Targets[])
    → ReplacementEffectManager (modifies parameters)
    → Effect (consumes Targets[], executes)
```

## Benefits of This Architecture

1. **Separation of Concerns**: Each component has one job
2. **Testability**: Individual components can be tested in isolation
3. **Maintainability**: Changes to targeting don't affect effect execution
4. **Extensibility**: New effects, targeting modes, or replacement effects are easy to add
5. **Type Safety**: Uses enum-based effect types
6. **Readability**: Small, focused classes instead of one huge file
7. **Reusability**: TargetResolver and ReplacementEffectManager are shared across all effects

## Migration Notes

The refactoring moved ~800 lines of effect execution code from AbilityManager.gd into separate classes.

### What Changed:
- ❌ **Removed**: `execute_*()` methods from AbilityManager
- ❌ **Removed**: `modifyCard()` and `_apply_*_modification()` methods from AbilityManager
- ❌ **Removed**: Target resolution logic from Effect classes
- ❌ **Removed**: Replacement effect logic from CreateTokenEffect
- ✅ **Added**: Individual Effect classes for each effect type
- ✅ **Added**: EffectFactory for creating effects
- ✅ **Added**: TargetResolver for centralized target resolution
- ✅ **Added**: ReplacementEffectManager for centralized replacement effects
- ✅ **Added**: CardModifier utility class for card modifications

### Compatibility:
All existing card definitions continue to work without changes. The interface at the AbilityManager level remains the same.
