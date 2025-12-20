# Unified Card Modification API

## Overview
Introduced a unified `modifyCard()` method in `AbilityManager.gd` that handles all types of card modifications with consistent behavior and duration tracking.

## The Unified API

### Main Method
```gdscript
modifyCard(target_card: Card, modification_type: String, modification_data: Dictionary, duration: String)
```

### Parameters
- **target_card**: The card to modify
- **modification_type**: Type of modification (see below)
- **modification_data**: Dictionary with modification-specific data
- **duration**: `"Permanent"`, `"EndOfTurn"`, or `"WhileSourceInPlay"`

### Modification Types

#### 1. Keyword Abilities
```gdscript
# Grant Spellshield until end of turn
modifyCard(creature, "keyword", {"keyword": "Spellshield"}, "EndOfTurn")

# Grant Flying permanently
modifyCard(creature, "keyword", {"keyword": "Flying"}, "Permanent")
```

#### 2. Card Types
```gdscript
# Make a creature into an Artifact creature until end of turn
modifyCard(creature, "type", {"type": "Artifact"}, "EndOfTurn")

# Permanently change type
modifyCard(creature, "type", {"type": "Enchantment"}, "Permanent")
```

#### 3. Subtypes
```gdscript
# Add Goblin subtype permanently (for grow-up mechanic)
modifyCard(child_token, "subtype", {"subtype": "Grown-up"}, "Permanent")

# Add subtype until end of turn
modifyCard(creature, "subtype", {"subtype": "Warrior"}, "EndOfTurn")
```

#### 4. Power Boost
```gdscript
# +3 power until end of turn (like Growth spell)
modifyCard(creature, "power_boost", {"amount": 3}, "EndOfTurn")

# +2 power permanently
modifyCard(creature, "power_boost", {"amount": 2}, "Permanent")
```

#### 5. Power Reduction
```gdscript
# -2 power until end of turn (debuff)
modifyCard(creature, "power_reduction", {"amount": 2}, "EndOfTurn")
```

## Legacy Functions (Still Work!)

For backwards compatibility, the old functions still work but now delegate to `modifyCard()`:

```gdscript
# These all work and use modifyCard internally:
grant_keyword_to_card(creature, "Spellshield", "EndOfTurn", game)
add_type_to_card(creature, "Grown-up", "Permanent", game)
apply_power_boost(creature, 3, "EndOfTurn")
```

## Benefits of Unified API

### 1. Consistency
All modifications follow the same pattern:
- Apply the change immediately
- Track for removal if not permanent
- Update card display
- Emit dirty signal

### 2. Extensibility
Easy to add new modification types:
```gdscript
# Future additions could be:
modifyCard(creature, "toughness_boost", {"amount": 2}, "EndOfTurn")
modifyCard(creature, "ability_grant", {"ability": custom_ability}, "WhileSourceInPlay")
modifyCard(creature, "cost_reduction", {"amount": 1}, "EndOfTurn")
```

### 3. Cleaner Code
Instead of:
```gdscript
grant_keyword_to_card(creature, "Flying", "EndOfTurn", game)
add_type_to_card(creature, "Warrior", "EndOfTurn", game)
apply_power_boost(creature, 3, "EndOfTurn")
```

You can now see all modifications follow the same pattern:
```gdscript
modifyCard(creature, "keyword", {"keyword": "Flying"}, "EndOfTurn")
modifyCard(creature, "subtype", {"subtype": "Warrior"}, "EndOfTurn")
modifyCard(creature, "power_boost", {"amount": 3}, "EndOfTurn")
```

### 4. Single Tracking System
All temporary effects go through `_track_modification_for_removal()`, ensuring:
- Consistent duration handling
- Unified cleanup in `game.gd`'s `cleanup_end_of_turn_effects()`
- No duplicate tracking code

## Implementation Details

### Internal Helper Methods
The public `modifyCard()` method delegates to internal helpers:
- `_apply_keyword_modification()`
- `_apply_type_modification()`
- `_apply_subtype_modification()`
- `_apply_power_modification()`
- `_track_modification_for_removal()` (shared by all)

### Automatic Updates
After any modification, the system automatically:
1. Updates the card's visual display
2. Emits the `dirty_data` signal for UI updates
3. Tracks temporary effects for cleanup

## Examples from Existing Cards

### Punglynd Hersir (Grant Spellshield)
```gdscript
# Old way (still works):
grant_keyword_to_card(creature, "Spellshield", "EndOfTurn", game)

# New unified way:
modifyCard(creature, "keyword", {"keyword": "Spellshield"}, "EndOfTurn")
```

### Growth Spell (+3 Power)
```gdscript
# Old way (still works):
apply_power_boost(creature, 3, "EndOfTurn")

# New unified way:
modifyCard(creature, "power_boost", {"amount": 3}, "EndOfTurn")
```

### Punglynd Child Grow-up (Add Subtype)
```gdscript
# Old way (still works):
add_type_to_card(child_token, "Grown-up", "Permanent", game)

# New unified way:
modifyCard(child_token, "subtype", {"subtype": "Grown-up"}, "Permanent")
```

## Migration Guide

No migration needed! The old functions still work. However, for new code, prefer using `modifyCard()` directly for consistency.

## Future Enhancements

Potential additions to the unified system:
- Toughness modifications (if you add toughness stat)
- Cost modifications
- Ability grants (not just keywords)
- Color changes
- Control changes
- Clone effects
