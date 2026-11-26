---
description: "Card definition DSL syntax, effect parameters, and structure for text files in Cards/ directory."
applyTo: "Cards/**/*.txt"
---

# Card DSL Specifications

## Source of Truth Rule
- Card definition files (`.txt` files inside `Cards/Cards/`, `Cards/OpponentCards/`, `Cards/Tokens/`) are the **source of truth** for game balance and abilities.
- If test assertions conflict with card definitions, card files are assumed correct and tests must be adjusted (or clarification requested from user).

## Card File Format

Card files are parsed by `Game/scripts/CardLoader.gd` line-by-line using key-value pairs before the `CardText:` marker:

```txt
Name:Card Name
Color:Red
Rarity:Common
Types:Spell
ManaCost:1
E:$ DealDamage | ValidTgts$ Any | NumDmg$ 3 | SpellDescription$ Deals 3 damage.
CardText: Deals 3 damage to any target.
```

### Key Fields
- `Name`: Full card name.
- `Color`: Color identifier (`Red`, `Blue`, `Green`, `Black`, `White`, `Colorless`, comma-separated if multicolor).
- `Rarity`: `Common`, `Uncommon`, `Rare`, `Mythic`.
- `Types`: Space-separated card types (e.g. `Creature`, `Spell`, `Relic`, `Token Creature`, `Boss Creature`) followed by any subtypes (e.g. `Creature Goblin`).
- `ManaCost`: Gold/resource cost integer.
- `Power`: Integer (for creatures).
- `Durability`: Integer (for relics/cards with durability).

### Ability & Effect Lines
Ability keys can appear multiple times:
- `E`: Spell effect line.
- `A`: Activated ability.
- `AA`: Alternative / additional ability.
- `T`: Triggered ability.
- `R`: Replacement effect.
- `K`: Keyword (e.g., `Charge`, `Taunt`, `Elusive`).
- `SVar`: Stored variable / script variable reference used in dynamic calculations.

### Syntax Rules
- Parameters within an ability/effect line are separated by ` | `.
- Effect specifications use `$` (e.g. `E:$ DealDamage | ValidTgts$ Any | NumDmg$ 3`).
- `CardText:` marks the beginning of the UI text box; everything after this tag represents display text.
- Consult `Game/scripts/EffectType.gd` and `Game/scripts/AbilityParser.gd` to confirm supported parameter names and effect types.
