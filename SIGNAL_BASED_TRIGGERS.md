# Signal-Based Trigger System

## Overview

The game now uses an **event-driven, object-oriented** architecture for triggered abilities.

### Architecture

**Class Hierarchy:**
```
CardAbility (base class)
├── TriggeredAbility (responds to game events via signals)
├── ActivatedAbility (player-initiated, costs + effects)
└── StaticAbility (continuous effects while in play)
```

**Key Principle:** Each ability **registers itself** to appropriate game signals. No more polling!

### Old System (Deprecated)
```
Game Action → Game searches all cards → Check each card for matching triggers → Execute
```

### New System (Current)
```
Card Enters Play → Abilities register themselves → Event fires → Ability adds to queue → Queue resolves
```

## Key Components

### 1. TriggeredAbility Class (`TriggeredAbility.gd`)
Self-registering abilities that respond to game events:

```gdscript
# Create a triggered ability
var ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
)
ability.with_effect_parameters({"token_name": "Goblin", "count": 1})
ability.with_trigger_condition("Self", true)

# Ability registers itself when enabled
ability.enable(game)  # Connects to game.card_entered_play signal
```

**Event-to-Signal Mapping:**
```gdscript
const EVENT_TO_SIGNAL = {
    GameEventType.ATTACK_DECLARED: "attack_declared",
    GameEventType.CARD_DIED: "card_died",
    GameEventType.CARD_ENTERED_PLAY: "card_entered_play",
    GameEventType.DAMAGE_DEALT: "damage_dealt",
    GameEventType.TURN_STARTED: "turn_started",
    GameEventType.SPELL_CAST: "spell_cast",
    GameEventType.END_OF_TURN: "end_of_turn",
    GameEventType.BEGINNING_OF_TURN: "beginning_of_turn"
}
```

### 2. ActivatedAbility Class (`ActivatedAbility.gd`)
Player-initiated abilities with activation costs:

```gdscript
var ability = ActivatedAbility.new(card_data, EffectType.Type.DEAL_DAMAGE)
ability.with_activation_cost({"type": "PayMana", "amount": 1})
ability.with_activation_cost({"type": "Tap", "target": "Self"})
ability.with_effect_parameters({"NumDamage": 2})
```

### 3. StaticAbility Class (`StaticAbility.gd`)
Continuous effects while card is in play:

```gdscript
var ability = StaticAbility.new(card_data, EffectType.Type.PUMP)
ability.with_effect_parameters({
    "PowerBonus": 1,
    "ValidCards": "Creature.YouCtrl+Goblin"
})
```

### 4. Game Signals (`game.gd`)
Game emits signals when events happen:
- `card_entered_play(card_data: CardData, context: Dictionary)`
- `card_died(card_data: CardData, context: Dictionary)`
- `attack_declared(card_data: CardData, context: Dictionary)`
- `spell_cast(card_data: CardData, context: Dictionary)`
- `damage_dealt(card_data: CardData, context: Dictionary)`
- `turn_started(context: Dictionary)`
- `turn_ended(context: Dictionary)`
- `beginning_of_turn(context: Dictionary)`
- `end_of_turn(context: Dictionary)`

### 2. TriggerQueue (`TriggerQueue.gd`)
FIFO queue that stores triggered abilities waiting to resolve:
- `add_trigger(source_card_data, ability, context)` - Add ability to queue
- `get_next_trigger()` - Get next trigger to resolve
- `has_triggers()` - Check if queue has triggers
- Supports both CardAbility objects and Dictionary format (backward compatible)

### 3. AbilityManager (`AbilityManager.gd`)
Manages ability registration and execution:
- `register_card_abilities(card_data, game)` - Calls `enable()` on all abilities
- `unregister_card_abilities(card_data, game)` - Calls `disable()` on all abilities
- `executeAbilityEffect(card_data, ability, game)` - Execute an ability's effect
- Accepts both new class-based and old Dictionary formats

### 4. CardAbility (`CardAbility.gd`)
Base class for all abilities with common functionality

## How It Works

### Step 1: Card Enters Play
When a card enters the battlefield, `executeCardEnters()` enables all abilities:
```gdscript
# game.gd
func executeCardEnters(card: Card, source_zone, target_zone):
    # ... movement code ...
    
    # Enable all abilities (they register themselves)
    AbilityManagerAL.register_card_abilities(card.cardData, self)
    
    # Emit event
    emit_game_event("card_entered_play", card.cardData, {...})
```

### Step 2: Abilities Register Themselves
Each `TriggeredAbility` connects to its signal:
```gdscript
# TriggeredAbility.gd
func enable(game: Node):
    var signal_name = EVENT_TO_SIGNAL[game_event_trigger]
    game.connect(signal_name, _on_game_event)  # Self-registration!
```

### Step 3: Event Fires, Ability Responds
When event happens, ability's callback checks conditions:
```gdscript
# TriggeredAbility.gd
func _on_game_event(event_card_data, context):
    # Check trigger conditions
    if not _check_trigger_conditions(...):
        return
    
    # Check zone requirements
    if not _check_trigger_location(...):
        return
    
    # Add to queue
    game.trigger_queue.add_trigger(owner_card_data, self, context)
```

### Step 4: Queue Resolves
Game resolves the trigger queue using `resolve_trigger_queue()`:
```gdscript
# game.gd
func resolve_trigger_queue():
    trigger_queue.start_resolving()
    
    while trigger_queue.has_triggers():
        var trigger = trigger_queue.get_next_trigger()
        await AbilityManagerAL.executeAbilityEffect(
            trigger.source_card_data,
            trigger.ability,
            self
        )
    
    trigger_queue.finish_resolving()
    resolveStateBasedAction()
```

## Migration Guide

### Converting Old Dictionary-Based Abilities to New Classes

**Old Format (Dictionary):**
```gdscript
{
    "type": "TriggeredAbility",
    "trigger": "Enters",
    "effect_type": "TokenCreation",
    "effect_parameters": {"token_name": "Goblin", "count": 1},
    "trigger_conditions": {"Self": true}
}
```

**New Format (TriggeredAbility class):**
```gdscript
var ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
)
ability.with_effect_parameters({"token_name": "Goblin", "count": 1})
ability.with_trigger_condition("Self", true)

# Add to CardData
card_data.abilities.append(ability)
```

### Conversion Helper
Use `from_dictionary()` static methods:
```gdscript
# Convert old dictionary to new class
var old_ability_dict = {...}
var new_ability = TriggeredAbility.from_dictionary(card_data, old_ability_dict)
```

### Using Both Formats
The system supports both formats during migration:
- `executeAbilityEffect()` accepts CardAbility or Dictionary
- `TriggerQueue` stores either type
- Old cards continue working while you migrate

## Benefits

1. **Encapsulation**: Each ability manages its own signal connection
2. **Performance**: No more searching all cards for triggers every action
3. **Scalability**: Works efficiently with any number of cards
4. **Clarity**: Abilities explicitly declare what events they care about
5. **Decoupling**: Game doesn't need to know about ability implementation details
6. **Type Safety**: Class-based system provides compile-time checking
7. **Flexibility**: Easy to add new event types or ability behaviors
8. **Self-Managing**: Abilities register and unregister themselves automatically

## Event Emission Points

Update these locations to use `emit_game_event()`:
- ✅ `executeCardEnters()` - card_entered_play
- ⏳ `putInOwnerGraveyard()` - card_died
- ⏳ `declareAttack()` - attack_declared
- ⏳ Combat damage - damage_dealt
- ⏳ Spell casting - spell_cast
- ⏳ Turn phases - turn_started, end_of_turn, etc.

## Debugging

Look for these debug messages:
- `📡 [ABILITY REGISTER]` - Ability registered to signal
- `⚡ [TRIGGER]` - Ability triggered, checking conditions
- `📋 [TRIGGER QUEUE]` - Added to queue
- `🔥 [ABILITY]` - Executing effect
- `✅ [QUEUE RESOLVED]` - Queue finished

## Future Work

1. ✅ Register abilities on card entry
2. ✅ Queue system implementation
3. ✅ Execute queue resolution
4. ⏳ Update all game event emission points
5. ⏳ Add ability unregistration when cards leave play
6. ⏳ Implement ValidCards filtering in trigger conditions
7. ⏳ Migrate all existing cards to CardAbility format
8. ⏳ Add unit tests for trigger system
