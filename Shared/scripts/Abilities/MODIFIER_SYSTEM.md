# Ability Modifier System

## Overview

The Ability Modifier System allows static abilities (like Goblin Warchief's replacement effect) to modify other abilities before they execute. Modifiers are checked when abilities enter the trigger queue, not during effect execution.

## Architecture

### Core Components

1. **AbilityModifier** (`AbilityModifier.gd`)
   - Represents a single modifier from a static ability
   - Checks if it applies to a given ability
   - Applies modifications to effect parameters

2. **AbilityModifierRegistry** (`AbilityModifierRegistry.gd`)
   - Global registry of all active modifiers
   - Automatically applies all applicable modifiers to abilities
   - Cleans up invalid modifiers

3. **StaticAbility** (updated)
   - Registers modifiers when enabled
   - Unregisters modifiers when disabled

### Data Flow

```
Card enters play
    ↓
StaticAbility.enable() called
    ↓
Modifier registered in AbilityModifierRegistry
    ↓
... (modifier is active) ...
    ↓
Triggered ability fires
    ↓
AbilityManager.executeAbilityEffect()
    ↓
AbilityModifierRegistry.apply_modifiers_to_effect()
    - Checks all registered modifiers
    - Applies those that match conditions
    - Modifies effect parameters
    ↓
Effect executes with modified parameters
```

## Creating a Modifier

### Card Definition

Example: Goblin Warchief (creates extra Goblin tokens)

```
S:Mode$ Continuous | Affected$ Card.YouCtrl+Creature.Goblin | AddKeyword$ Haste
S:Mode$ ReplacementEffect | EventType$ CreateToken | ValidToken$ Card.YouCtrl+Creature.Goblin | ActiveZones$ Battlefield | Type$ AddToken | Amount$ 1
```

### Modifier Properties

When parsed into a StaticAbility:

```gdscript
{
	"type": "StaticAbility",
	"effect_type": "ReplacementEffect",  # or appropriate type
	"effect_parameters": {
		"Type": "AddToken",              # Modifier type
		"Amount": "1",                   # Modification value
		"replacement_conditions": {
			"EventType": "CreateToken",  # What ability type to modify
			"ValidToken": "Card.YouCtrl+Creature.Goblin",  # Filter
			"ActiveZones": "Battlefield"  # Where modifier must be active
		}
	}
}
```

## Supported Modifier Types

### 1. AddToken
Adds additional tokens when tokens are created.

**Properties:**
- `Type`: "AddToken"
- `Amount`: Number of additional tokens (string, e.g., "1")

**Conditions:**
- `EventType`: "CreateToken"
- `ValidToken`: Filter for which tokens (e.g., "Card.YouCtrl+Creature.Goblin")
- `ActiveZones`: Where the source must be (e.g., "Battlefield")

**Example:**
```gdscript
{
	"Type": "AddToken",
	"Amount": "1",
	"replacement_conditions": {
		"EventType": "CreateToken",
		"ValidToken": "Card.YouCtrl+Creature.Goblin",
		"ActiveZones": "Battlefield"
	}
}
```

### 2. IncreaseDamage
Increases damage dealt by abilities.

**Properties:**
- `Type`: "IncreaseDamage"
- `Amount`: Additional damage (string, e.g., "2")

**Conditions:**
- `EventType`: "DealDamage"
- `ValidSource`: Filter for damage source
- `ActiveZones`: Where the source must be

**Example:**
```gdscript
{
	"Type": "IncreaseDamage",
	"Amount": "2",
	"replacement_conditions": {
		"EventType": "DealDamage",
		"ValidSource": "Card.YouCtrl",
		"ActiveZones": "Battlefield"
	}
}
```

### 3. MultiplyTokens
Multiplies the number of tokens created.

**Properties:**
- `Type`: "MultiplyTokens"
- `Multiplier`: Multiplication factor (string, e.g., "2")

**Conditions:**
- `EventType`: "CreateToken"
- `ValidToken`: Filter for which tokens
- `ActiveZones`: Where the source must be

## Adding New Modifier Types

### 1. Define the Modifier Type

Add a new case to `AbilityModifier.apply_modifications()`:

```gdscript
match modifier_type:
	"MyNewModifier":
		# Apply your modification
		var my_value = modifications.get("MyValue", "0")
		modified_params["my_param"] = my_value
		print("  📝 [MODIFIER] Applied MyNewModifier")
```

### 2. Add Condition Checking (if needed)

Add a new method to `AbilityModifier`:

```gdscript
func _check_my_conditions(effect_parameters: Dictionary) -> bool:
	# Check if this modifier should apply
	return true
```

And call it from `applies_to_ability()`:

```gdscript
match standardized_event:
	"MyEffectType":
		return _check_my_conditions(effect_parameters)
```

### 3. Update Documentation

Document your new modifier type in this file and in card definition guides.

## API Reference

### AbilityModifier

```gdscript
# Constructor
func _init(source: CardData, type: String, cond: Dictionary, mods: Dictionary)

# Check if modifier applies
func applies_to_ability(ability_effect_type: String, effect_parameters: Dictionary, game_context: Game) -> bool

# Apply modifications
func apply_modifications(effect_parameters: Dictionary) -> Dictionary
```

### AbilityModifierRegistry

```gdscript
# Register a modifier
static func register_modifier(modifier: AbilityModifier)

# Unregister a modifier
static func unregister_modifier(modifier: AbilityModifier)

# Unregister all modifiers from a card
static func unregister_all_for_card(card_data: CardData)

# Apply all applicable modifiers to an effect
static func apply_modifiers_to_effect(effect_type: String, effect_parameters: Dictionary, game_context: Game) -> Dictionary

# Cleanup
static func clear_all()
```

### StaticAbility Updates

```gdscript
# Automatically registers/unregisters modifiers
func enable(game: Node)   # Registers modifier
func disable(game: Node)  # Unregisters modifier
```

## Examples

### Example 1: Goblin Warchief (Add Token)

**Card Text**: "Whenever a Goblin token would be created, create two instead."

**Implementation**:
```gdscript
var static_ability = StaticAbility.new(card_data, EffectType.Type.REPLACEMENT_EFFECT)
static_ability.effect_parameters = {
	"Type": "AddToken",
	"Amount": "1",
	"replacement_conditions": {
		"EventType": "CreateToken",
		"ValidToken": "Card.YouCtrl+Creature.Goblin",
		"ActiveZones": "Battlefield"
	}
}
```

**Result**: When `Goblin Emblem` creates a Goblin token, the modifier adds +1, creating 2 tokens total.

### Example 2: Damage Amplifier

**Card Text**: "If a source you control would deal damage, it deals that much damage plus 2 instead."

**Implementation**:
```gdscript
var static_ability = StaticAbility.new(card_data, EffectType.Type.REPLACEMENT_EFFECT)
static_ability.effect_parameters = {
	"Type": "IncreaseDamage",
	"Amount": "2",
	"replacement_conditions": {
		"EventType": "DealDamage",
		"ValidSource": "Card.YouCtrl",
		"ActiveZones": "Battlefield"
	}
}
```

## Debugging

### Print Active Modifiers

```gdscript
AbilityModifierRegistry.debug_print_modifiers()
```

### Check Modifier Count

```gdscript
var count = AbilityModifierRegistry.get_modifier_count()
print("Active modifiers: ", count)
```

### Enable Verbose Logging

Modifiers automatically print when they're applied:
```
📝 [MODIFIER] Goblin Warchief adds 1 token(s). Total: 2
✅ Applied 1 modifier(s) to CreateToken
```

## Best Practices

1. **Always set ActiveZones**: Most modifiers should only work from specific zones (usually "Battlefield")

2. **Use specific filters**: Use `ValidToken`, `ValidSource`, etc. to make modifiers as specific as possible

3. **Test edge cases**: What happens when multiple modifiers apply? They stack!

4. **Clean up**: StaticAbility automatically unregisters modifiers when disabled, but you can manually clean up with `AbilityModifierRegistry.unregister_all_for_card()`

5. **Avoid side effects**: Modifiers should only modify parameters, not execute effects or change game state

## Migration from Old System

### Before (in CreateTokenEffect):
```gdscript
func execute(parameters: Dictionary, source_card_data: CardData, game_context: Game):
	var effect_context = _apply_replacement_effects(...)  # ❌ Wrong place
	var tokens_to_create = effect_context.get("tokens_to_create", 1)
	# ...
```

### After (in AbilityManager):
```gdscript
func executeAbilityEffect(source_card_data: CardData, ability, game_context: Game):
	var resolved_parameters = effect_parameters.duplicate()
	
	# ✅ Apply modifiers at ability level, before effect execution
	resolved_parameters = AbilityModifierRegistry.apply_modifiers_to_effect(
		effect_type_str, 
		resolved_parameters, 
		game_context
	)
	
	await EffectFactory.execute_effect(effect_type_enum, resolved_parameters, ...)
```

## Future Enhancements

- [ ] Support for cost modifiers (reduce mana costs, etc.)
- [ ] Support for targeting modifiers (change valid targets)
- [ ] Support for conditional modifiers (only during combat, etc.)
- [ ] Support for priority/ordering when multiple modifiers apply
- [ ] Support for "instead" replacement effects (completely replace, not modify)
