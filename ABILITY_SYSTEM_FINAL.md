# Ability System - Final Architecture

## Core Principle
**Abilities manage themselves from creation to destruction.**

## Key Changes

### ❌ REMOVED: `register_card_abilities()`
The old centralized registration method is **gone**. No more:
```gdscript
# OLD - Don't do this anymore
AbilityManagerAL.register_card_abilities(card.cardData, self)
```

### ✅ NEW: Abilities enable themselves when created
```gdscript
# Create ability
var ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
)

# Enable immediately - ability registers itself to game signals
ability.enable(game)

# Add to card
card_data.abilities.append(ability)
```

## Complete Flow

### 1. CardData Creation
```gdscript
# In CardLoader or wherever cards are created
func create_card_with_abilities(game: Game) -> CardData:
    var card_data = CardData.new()
    card_data.cardName = "Goblin Matron"
    
    # Create and enable triggered ability
    var ability = TriggeredAbility.new(
        card_data,
        TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
        EffectType.Type.CREATE_TOKEN
    )
    ability.with_effect_parameters({"token_name": "Goblin", "count": 1})
    ability.with_trigger_condition("Self", true)
    
    # Enable immediately - connects to game.card_entered_play signal
    ability.enable(game)
    
    card_data.abilities.append(ability)
    return card_data
```

### 2. Card Enters Play
```gdscript
# game.gd
func executeCardEnters(card: Card, source_zone, target_zone):
    # Move card to battlefield
    # ...movement code...
    
    # Abilities are ALREADY listening to signals!
    # Just emit the event
    emit_game_event("card_entered_play", card.cardData, {...})
```

### 3. Ability Automatically Responds
```gdscript
# TriggeredAbility.gd - Already connected in enable()
func _on_game_event(event_card_data, context):
    # Check conditions
    if not _check_trigger_conditions(...):
        return
    
    # Add to queue
    game.trigger_queue.add_trigger(owner_card_data, self, context)
```

### 4. Queue Resolves
```gdscript
# game.gd
func resolve_trigger_queue():
    while trigger_queue.has_triggers():
        var trigger = trigger_queue.get_next_trigger()
        await AbilityManagerAL.executeAbilityEffect(...)
```

## Lifecycle Management

### When CardData is Created
```gdscript
var ability = TriggeredAbility.new(card_data, event, effect)
ability.enable(game)  // Connects to signal
card_data.abilities.append(ability)
```

### When Card Leaves Play
```gdscript
# Call disable on abilities that need cleanup
for ability in card_data.abilities:
    if ability is TriggeredAbility:
        ability.disable(game)  // Disconnects from signal
```

## AbilityManager's New Role

AbilityManager **no longer manages registration**. It only:
1. Executes ability effects (`executeAbilityEffect()`)
2. Handles activated abilities (`activateAbility()`)
3. Provides utility methods for effect execution

```gdscript
# AbilityManager.gd - Simplified!
extends Node
class_name AbilityManager

# No more registration methods!
# Abilities handle themselves

func executeAbilityEffect(source_card_data, ability, game):
    # Execute the effect
    
func activateAbility(source_card, ability, game):
    # Handle player-activated abilities
```

## Benefits

1. **No Middleman**: Abilities connect directly to signals
2. **Earlier Registration**: Abilities active as soon as created
3. **Clearer Ownership**: Each ability manages its own lifecycle
4. **Less Code**: No registration loop needed
5. **Explicit**: `ability.enable(game)` is clear and intentional

## Migration Checklist

- [ ] Remove all calls to `AbilityManagerAL.register_card_abilities()`
- [ ] In card creation code, call `ability.enable(game)` immediately after creating each ability
- [ ] Verify `emit_game_event()` is called when events occur
- [ ] Test that abilities trigger correctly
- [ ] Remove any unused registration methods

## Example: Complete Card Creation

```gdscript
func create_goblin_matron(game: Game) -> CardData:
    var card_data = CardData.new()
    card_data.cardName = "Goblin Matron"
    card_data.power = 2
    card_data.types = [CardData.CardType.CREATURE]
    card_data.subtypes = ["Goblin"]
    
    # Triggered: "When this enters, create a Goblin token"
    var etb_ability = TriggeredAbility.new(
        card_data,
        TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
        EffectType.Type.CREATE_TOKEN
    )
    etb_ability.with_effect_parameters({"token_name": "Goblin", "count": 1})
    etb_ability.with_trigger_condition("Self", true)
    etb_ability.enable(game)  # Register to signal NOW
    card_data.abilities.append(etb_ability)
    
    # Activated: "Tap: Deal 1 damage"
    var activated = ActivatedAbility.new(card_data, EffectType.Type.DEAL_DAMAGE)
    activated.with_activation_cost({"type": "Tap", "target": "Self"})
    activated.with_effect_parameters({"NumDamage": 1, "ValidTargets": "Creature"})
    card_data.abilities.append(activated)
    
    # Static: "Other Goblins get +1/+1"
    var static = StaticAbility.new(card_data, EffectType.Type.PUMP)
    static.with_effect_parameters({
        "PowerBonus": 1,
        "ValidCards": "Creature.YouCtrl+Goblin+Other"
    })
    static.enable(game)  # Apply effect NOW
    card_data.abilities.append(static)
    
    return card_data
```

## Summary

**Old Way:**
```
Create CardData → Card enters play → Game calls register_card_abilities() → Abilities connect
```

**New Way:**
```
Create CardData → Create ability → ability.enable() → Card enters play → Abilities already listening!
```

The registration happens **at creation time**, not when the card enters play. This is cleaner, more efficient, and more intuitive.
