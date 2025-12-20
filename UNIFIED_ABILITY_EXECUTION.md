# Unified Ability Execution Refactoring

## Overview
Refactored the ability system to use a single unified `executeAbilityEffect()` method for all ability effect execution, regardless of how the ability was triggered (activated vs triggered).

## Key Concept

**The means of triggering an ability is separate from executing its effect:**
- **Triggered abilities**: Triggered automatically by game events (card enters, attacks, phase changes)
- **Activated abilities**: Triggered by player action with cost payment (Tap, Sacrifice, Pay Mana)
- **Effect execution**: Once triggered/activated, both use the same unified method

## Changes Made

### 1. Renamed Function
```gdscript
# Before
executeActivatedAbilityEffect(source_card, ability, game_context)

# After  
executeAbilityEffect(source_card, ability, game_context)
```

### 2. Unified Entry Point
Both triggered and activated abilities now use `executeAbilityEffect()`:

```gdscript
# Triggered abilities (automatic)
func triggerGameAction(game: Game, action: GameAction):
    # ...find triggered abilities...
    for abilityPair in triggeredAbilities:
        await executeAbilityEffect(triggeringCard, ability, game)  # ← Unified

# Activated abilities (player-initiated)
func activateAbility(source_card: Card, activated_ability: Dictionary, game_context: Game):
    # ...check and pay costs...
    await executeAbilityEffect(source_card, ability, game_context)  # ← Unified
```

### 3. Dual Format Support
The unified method handles both modern and legacy ability formats:

```gdscript
func executeAbilityEffect(source_card: Card, ability: Dictionary, game_context: Game):
    var effect_type = ability.get("effect_type", "")      # Modern format (activated abilities)
    var effect_name = ability.get("effect_name", "")      # Legacy format (old triggered abilities)
    
    # Modern format: effect_type
    if not effect_type.is_empty():
        match effect_type:
            "PumpAll", "Token", "Draw", "AddType": ...
    
    # Legacy format: effect_name  
    elif not effect_name.is_empty():
        match effect_name:
            "TrigToken", "TrigDraw", "TrigGrowup": ...
```

### 4. Removed Duplicate Function
Deleted the old `executeAbility()` function that only handled triggered abilities.

## Architecture Flow

### Triggered Ability Flow
```
Game Event Occurs
    ↓
triggerGameAction()
    ↓
Find matching triggered abilities
    ↓
executeAbilityEffect() ← Unified entry point
    ↓
Effect execution (Token, Draw, AddType, PumpAll, etc.)
```

### Activated Ability Flow
```
Player clicks card
    ↓
tryActivateAbility()
    ↓
activateAbility()
    ↓
canPayActivationCosts() → Check if costs can be paid
    ↓
payActivationCosts() → Pay Tap/Sacrifice/Mana costs
    ↓
executeAbilityEffect() ← Unified entry point
    ↓
Effect execution (Token, Draw, AddType, PumpAll, etc.)
```

## Supported Effect Types

### Modern Format (effect_type)
Used by activated abilities and new cards:
- `"PumpAll"` - Grant keywords to multiple creatures
- `"Token"` - Create token creatures
- `"Draw"` - Draw cards
- `"AddType"` - Add types/subtypes to cards

### Legacy Format (effect_name)
Used by older triggered abilities:
- `"TrigToken"` - Create token creatures
- `"TrigDraw"` - Draw cards  
- `"TrigGrowup"` - Add Grown-up subtype

## Benefits

### 1. Single Source of Truth
All ability effects execute through one method, making it easier to:
- Add new effect types
- Debug effect execution
- Maintain consistent behavior

### 2. Clear Separation of Concerns
```gdscript
# Triggering/Activation (different)
- Triggered: Automatic based on game events
- Activated: Player-initiated with costs

# Effect Execution (same)
- Both use executeAbilityEffect()
- Effect logic is identical regardless of trigger mechanism
```

### 3. Easier to Extend
Adding a new effect type only requires:
1. Add to the `match effect_type` in `executeAbilityEffect()`
2. Implement the effect execution function
3. Works automatically for both triggered AND activated abilities

### 4. Reduced Code Duplication
- Before: Two separate functions with similar logic
- After: One unified function with dual format support

## Examples

### Punglynd Hersir (Activated Ability)
```gdscript
# Card text: AA:$ PumpAll | Cost$ Sac.Self+Pay.1 | ValidCards$ Creature.YouCtrl | KW$ Spellshield | Duration$ EndOfTurn

# Flow:
1. Player left-clicks Hersir
2. tryActivateAbility() → activateAbility()
3. Costs paid: Sacrifice Hersir + Pay 1 gold
4. executeAbilityEffect() with effect_type="PumpAll"
5. All your creatures gain Spellshield until end of turn
```

### Punglynd Childbearer (Triggered Ability)
```gdscript
# Card text: T:$ Battlefield | E$ TrigToken | TokenScript$ Punglynd_Child | Amount$ 1

# Flow:
1. Childbearer enters battlefield
2. triggerGameAction() detects CARD_ENTERS
3. executeAbilityEffect() with effect_name="TrigToken"
4. Punglynd Child token created
```

### Punglynd Child (Triggered Ability - Grow Up)
```gdscript
# Card text: T:$ EndOfTurn | Condition$ Self.Attacked+ThisTurn | E$ TrigGrowup | Target$ Self | Types$ Grown-up

# Flow:
1. End of turn phase
2. triggerGameAction() checks condition (attacked this turn)
3. executeAbilityEffect() with effect_name="TrigGrowup"
4. Child gains Grown-up subtype permanently
```

## Migration Notes

### For Developers
- Old `executeActivatedAbilityEffect()` calls automatically redirected to `executeAbilityEffect()`
- No changes needed to existing card definitions
- New abilities can use either format

### For Card Designers
Both formats work:
```
# Modern format (preferred for new cards)
AA:$ PumpAll | Cost$ Tap.Self | ValidCards$ Creature.YouCtrl | KW$ Flying | Duration$ EndOfTurn

# Legacy format (still supported)
T:$ CardEnters | E$ TrigToken | TokenScript$ Goblin_Token
```

## Future Improvements

Potential enhancements to the unified system:
- Migrate all legacy `effect_name` to modern `effect_type` format
- Add more effect types (Destroy, Bounce, Exile, etc.)
- Support effect chains (one ability triggering another)
- Add effect interrupt/counter mechanics
