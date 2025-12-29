# New Ability Class Architecture

## Overview
Abilities now manage themselves! Each ability class knows how to register/unregister from game signals.

## Class Hierarchy

```
CardAbility (base class)
├── TriggeredAbility (self-registering to game signals)
├── ActivatedAbility (player-initiated, no registration needed)
└── StaticAbility (continuous effects, applies on enable)
```

## Key Design Principles

1. **Self-Managing**: Abilities register and unregister themselves
2. **Encapsulation**: Signal connection logic lives in the ability class
3. **No Polling**: Game doesn't search for triggers, abilities listen for events

## Creating Abilities

### TriggeredAbility
```gdscript
var ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
)
ability.with_effect_parameters({"token_name": "Goblin", "count": 1})
ability.with_trigger_condition("Self", true)

# Ability self-registers when enabled
ability.enable(game)
```

### ActivatedAbility
```gdscript
var ability = ActivatedAbility.new(card_data, EffectType.Type.DEAL_DAMAGE)
ability.with_activation_cost({"type": "PayMana", "amount": 1})
ability.with_activation_cost({"type": "Tap", "target": "Self"})
ability.with_effect_parameters({"NumDamage": 2})
```

### StaticAbility
```gdscript
var ability = StaticAbility.new(card_data, EffectType.Type.PUMP)
ability.with_effect_parameters({
    "PowerBonus": 1,
    "ValidCards": "Creature.YouCtrl+Goblin"
})

# Applies continuous effect when enabled
ability.enable(game)
```

## Event-to-Signal Mapping

TriggeredAbility has a built-in mapping table:

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

## How It Works

### 1. Create CardData with Abilities
```gdscript
# Create card data
var card_data = CardData.new()
card_data.cardName = "Goblin Matron"

# Create triggered ability
var ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
)
ability.with_effect_parameters({"token_name": "Goblin", "count": 1})

# Enable ability immediately - it registers itself to game signals
ability.enable(game)

# Add to card
card_data.abilities.append(ability)
```

### 2. Card Enters Play
```gdscript
# game.gd
func executeCardEnters(card: Card, source_zone, target_zone):
    # Abilities are already enabled and listening!
    # Just emit the event
    emit_game_event("card_entered_play", card.cardData, {...})
```

### 3. TriggeredAbility Already Listening
```gdscript
# TriggeredAbility.gd
# Already connected in enable():
func enable(game: Node):
    var signal_name = EVENT_TO_SIGNAL[game_event_trigger]
    game.connect(signal_name, _on_game_event)  # Self-registration!
```

### 4. Signal Fires, Ability Responds
```gdscript
# TriggeredAbility.gd
func _on_game_event(event_card_data, context):
    if not _check_trigger_conditions(...):
        return
    if not _check_trigger_location(...):
        return
    
    # Add to trigger queue
    game.trigger_queue.add_trigger(owner_card_data, self, context)
```

### 5. Game Resolves Queue
```gdscript
# game.gd
func resolve_trigger_queue():
    while trigger_queue.has_triggers():
        var trigger = trigger_queue.get_next_trigger()
        await AbilityManagerAL.executeAbilityEffect(
            trigger.source_card_data,
            trigger.ability,
            self
        )
```

## Benefits

1. **Encapsulation**: Each ability manages its own lifecycle
2. **Scalability**: No iteration over all cards to find triggers
3. **Flexibility**: Easy to add new ability types
4. **Type Safety**: Compile-time checking with classes
5. **Clarity**: Intent is clear from class type
6. **Self-Documenting**: Code structure mirrors game concepts

## Migration Path

### From Dictionary Format
```gdscript
# Old
var old_ability = {
    "type": "TriggeredAbility",
    "trigger": "Enters",
    "effect_type": "TokenCreation",
    "effect_parameters": {"token_name": "Goblin"}
}

# New
var new_ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
).with_effect_parameters({"token_name": "Goblin"})
```

### Conversion Helper
```gdscript
# Use from_dictionary() for batch conversion
var ability = TriggeredAbility.from_dictionary(card_data, old_dict)
```

## Legacy Support

During migration, the system supports:
- ✅ TriggeredAbility, ActivatedAbility, StaticAbility (new)
- ✅ Dictionary format (legacy, temporary)

AbilityManager handles both formats transparently.

## Adding New Event Types

1. Add to `TriggeredAbility.GameEventType` enum
2. Add to `EVENT_TO_SIGNAL` mapping
3. Add signal to `game.gd`
4. Emit signal where event occurs

That's it! Abilities automatically work with new events.

## Example: Full Card Setup

```gdscript
# Create card data
var card_data = CardData.new()
card_data.cardName = "Goblin Matron"

# Add triggered ability: "When this enters play, create a Goblin token"
var enter_ability = TriggeredAbility.new(
    card_data,
    TriggeredAbility.GameEventType.CARD_ENTERED_PLAY,
    EffectType.Type.CREATE_TOKEN
)
enter_ability.with_effect_parameters({"token_name": "Goblin", "count": 1})
enter_ability.with_trigger_condition("Self", true)

# Enable ability - it registers itself to game signals
enter_ability.enable(game)

# Add to card
card_data.abilities.append(enter_ability)

# Add activated ability: "Pay 1, Tap: Deal 1 damage"
var activated = ActivatedAbility.new(card_data, EffectType.Type.DEAL_DAMAGE)
activated.with_activation_cost({"type": "PayMana", "amount": 1})
activated.with_activation_cost({"type": "Tap", "target": "Self"})
activated.with_effect_parameters({"NumDamage": 1})
card_data.abilities.append(activated)

# When card enters play, triggered abilities already listening!
# Just emit the event and they respond
```
