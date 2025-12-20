# Effect Type Enum System

## Overview
The card game now uses a **type-safe enum-based system** for all effect types. This eliminates the dual format problem (effect_type vs effect_name) and provides compile-time checking for effect types.

## Architecture

### EffectType Enum (`Game/scripts/EffectType.gd`)
Central enum defining all possible effect types in the game:

```gdscript
enum Type {
    DEAL_DAMAGE,   # Deal damage to target(s)
    PUMP,          # Temporarily boost creature power
    DRAW,          # Draw cards
    CREATE_TOKEN,  # Create token creatures
    ADD_TYPE,      # Add types/subtypes to cards
    ADD_KEYWORD,   # Grant keyword abilities
    DESTROY,       # Destroy permanents
    BOUNCE,        # Return to hand
    EXILE,         # Exile cards
    MILL,          # Mill cards from deck
    DISCARD,       # Discard cards
    SEARCH,        # Search library
    SHUFFLE,       # Shuffle deck
}
```

### Conversion Functions
- `EffectType.string_to_type(str)` - Convert string to enum (used during card loading)
- `EffectType.type_to_string(enum)` - Convert enum to string (for debugging/display)
- `EffectType.requires_targeting(enum)` - Check if effect needs targets
- `EffectType.is_spell_effect(enum)` - Check if effect is a spell effect
- `EffectType.is_triggered_effect(enum)` - Check if effect is a triggered ability effect

## Card Definition Format

### Modern Format (Required)
All cards must use the modern `effect_type` format:

**Triggered Abilities:**
```
T:Mode$ CardEnters | Origin$ Any | Destination$ Battlefield | ValidCard$ Card.Self | Execute$ TrigToken | TriggerDescription$ When CARDNAME enters, create a token.
SVar:TrigToken:DB$ Token | TokenScript$ goblin
```
→ Parsed as `effect_type: "CreateToken"`

**Spell Effects:**
```
E:$ Pump | ValidTgts$ Creature | Pow$ 3 | Duration$ EndOfTurn | SpellDescription$ Target creature gets +3 power until end of turn.
```
→ Parsed as `effect_type: "Pump"`

**Activated Abilities:**
```
AA:$ PumpAll | Cost$ Tap.Self | ValidCards$ Creature.YouCtrl | KW$ Spellshield | Duration$ EndOfTurn | Description$ Tap: Your creatures gain Spellshield until end of turn.
```
→ Parsed as `effect_type: "AddKeyword"` (PumpAll is alias for AddKeyword)

### Legacy Format Migration
The CardLoader automatically converts legacy effect names to modern format during parsing:
- `TrigToken` → `CreateToken`
- `TrigDraw` → `Draw`
- `TrigGrowup` → `AddType`

**No fallback support in runtime** - All legacy formats are converted at parse time.

## Implementation Flow

### 1. Card Loading (CardLoader.gd)
```gdscript
# Parse triggered ability
var ability_data = {
    "type": "TriggeredAbility",
    "effect_type": "",  # Modern format only
    "effect_parameters": {},
    ...
}

# Convert legacy Execute$ name to modern effect_type
ability_data.effect_type = _normalize_effect_name(legacy_effect_name)
```

### 2. Ability Execution (AbilityManager.gd)
```gdscript
func executeAbilityEffect(source_card: Card, ability: Dictionary, game_context: Game):
    var effect_type_str = ability.get("effect_type", "")
    var effect_type_enum: EffectType.Type = EffectType.string_to_type(effect_type_str)
    
    match effect_type_enum:
        EffectType.Type.DEAL_DAMAGE:
            await execute_spell_damage_effect(...)
        EffectType.Type.PUMP:
            await execute_pump_effect(...)
        EffectType.Type.CREATE_TOKEN:
            execute_token_creation(...)
        ...
```

## Supported Effect Types

### Spell Effects
| Effect Type | Description | Parameters |
|------------|-------------|------------|
| `DealDamage` | Deal damage to target | `NumDamage`, `ValidTargets` |
| `Pump` | Boost creature power | `PowerBonus`, `Duration`, `ValidTargets` |
| `Draw` | Draw cards | `NumCards`, `Defined` |
| `Destroy` | Destroy permanent | `ValidTargets` |
| `Bounce` | Return to hand | `ValidTargets` |
| `Exile` | Exile card | `ValidTargets` |
| `Mill` | Mill from deck | `NumCards` |
| `Discard` | Discard cards | `NumCards` |

### Triggered/Activated Effects
| Effect Type | Description | Parameters |
|------------|-------------|------------|
| `CreateToken` | Create token | `TokenScript` |
| `Draw` | Draw cards | `NumCards`, `Defined` |
| `AddType` | Add types/subtypes | `Types`, `Target`, `Duration` |
| `AddKeyword` | Grant keyword | `KW`, `Duration`, `ValidCards` |

## Benefits

### 1. Type Safety
- Compile-time checking for effect types
- No typos or string mismatches
- IDE autocomplete support

### 2. Single Source of Truth
- All effect types defined in one enum
- No dual format confusion (effect_type vs effect_name)
- Consistent across all ability types

### 3. Easy Extension
- Add new effect types in one place (EffectType.gd)
- Automatic support in all ability types
- Clear documentation of all available effects

### 4. Better Error Messages
```
❌ Unknown effect type string: "Punp" - Please update card definitions to use modern format
```
Instead of silently failing or using wrong effect.

## Testing

All tests verify the enum-based system:
- `test_growth_spell_pump()` - Tests Pump effect with enum
- `test_activated_ability_pump_all()` - Tests AddKeyword (PumpAll) with enum
- `test_token_creation()` - Tests CreateToken with enum
- `test_draw_trigger()` - Tests Draw with enum

## Migration Guide

### For Existing Cards
1. Cards are automatically migrated at load time
2. Legacy formats (`TrigToken`, `TrigDraw`) are converted to modern (`CreateToken`, `Draw`)
3. No manual changes needed to card files

### For New Cards
Use modern effect type strings directly:
- ✅ `Execute$ TrigToken` (auto-converted to `CreateToken`)
- ✅ `E:$ Pump` (parsed as `Pump`)
- ✅ `AA:$ PumpAll` (parsed as `AddKeyword`)

### For Code Changes
- Use `EffectType.Type` enum in all new code
- Convert strings to enum with `EffectType.string_to_type()`
- Never use string matching in effect execution logic

## Future Work

### Potential Enhancements
1. **Card File Format Update**: Update all card `.txt` files to use modern names directly
2. **Additional Effect Types**: Add more effects (Heal, Transform, Clone, etc.)
3. **Composite Effects**: Support multiple effects in single ability
4. **Effect Modifiers**: Stack multiple effects (e.g., Pump + AddKeyword)

### Deprecation Plan
1. ✅ Phase 1: Remove runtime legacy support (COMPLETED)
2. 🔄 Phase 2: Update all card files to use modern names
3. ⏳ Phase 3: Remove `_normalize_effect_name()` helper
