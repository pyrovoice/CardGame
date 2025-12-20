# Spell Targeting Refactoring Summary

## Overview
Eliminated code duplication in spell effect targeting by centralizing card filtering logic into the existing GameUtility class.

## Changes Made

### 1. Enhanced GameUtility.gd (/Users/maximegrazzini/Documents/CardGame/Game/scripts/GameUtility.gd)
- Added centralized card filtering logic with AND (+) and OR (/) support
- Functions added:
  - `filterCardsByParameters(cards, filter, game)` - Main filtering function
  - `parseCriteria(filter_str)` - Parse filter strings into structured criteria
  - `process_filter_part(part, criteria)` - Process individual filter components
  - `matchesAllCriteria(card, criteria, game)` - Check if card matches all criteria

### 2. Updated AbilityManager.gd
- **executeSpellDamage()**: Replaced match-based targeting with `GameUtility.filterCardsByParameters()`
  - Removed: ~20 lines of duplicated match/for-loop logic
  - Now: 3 lines calling GameUtility
  
- **executeSpellPump()**: Replaced match-based targeting with `GameUtility.filterCardsByParameters()`
  - Removed: ~20 lines of duplicated match/for-loop logic
  - Now: 3 lines calling GameUtility

### 3. Updated CardPaymentManager.gd
- **filterCardsByParameters()**: Now delegates to GameUtility for consistency
- Removed: ~160 lines of filtering implementation
- Removed: `parseCriteria()`, `process_filter_part()`, `matchesAllCriteria()` helper functions
- Now: Simple 3-line wrapper calling GameHelper

## Benefits

### Code Quality
- **DRY Principle**: Eliminated ~200 lines of duplicated filtering logic
- **Single Source of Truth**: All card filtering now uses the same implementation
- **Maintainability**: Future filter changes only need to happen in one place

### Functionality
- All existing filters continue to work (AND/OR logic, controller, types, subtypes, cost/power ranges)
- No behavior changes - pure refactoring
- Supports complex filters like "Card.YouCtrl+Creature+Cost.1" or "Creature/Spell"

## Testing
The refactoring preserves all existing functionality:
- Growth spell (Pump effect) still works
- Bolt spell (Damage effect) still works
- Card payment system still works
- All card filtering criteria still supported

## Filter Syntax Reference
### Examples
- `"Any"` - Matches all cards
- `"Creature"` - All creatures
- `"Card.YouCtrl+Creature"` - Your creatures (AND logic with +)
- `"Creature/Spell"` - Creatures or spells (OR logic with /)
- `"Creature+Cost.1"` - 1-cost creatures
- `"Creature+MinCost.2+MaxCost.4"` - Creatures costing 2-4 gold
- `"Token"` - Only tokens
- `"NonToken+Goblin"` - Non-token goblins
- `"Creature+MinPower.3"` - Creatures with power 3 or greater

### Supported Criteria
- **Controller**: `YouCtrl`, `OppCtrl`, `Card.YouCtrl`, `Card.OppCtrl`
- **Card Types**: `Creature`, `Spell`, `Land`, `Artifact`, `Enchantment`
- **Subtypes**: Any string (e.g., `Goblin`, `Human`, `Punglynd`)
- **Token Status**: `Token`, `NonToken`
- **Cost**: `Cost.X`, `MinCost.X`, `MaxCost.X`
- **Power**: `Power.X`, `MinPower.X`, `MaxPower.X`

## Next Steps
Future spell effects (e.g., Destroy, Bounce, Draw) can use `GameUtility.filterCardsByParameters()` for targeting without duplicating code.
