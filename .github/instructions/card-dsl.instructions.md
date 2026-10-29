---
description: "Card definition DSL syntax, effect parameters, and structure for text files in Cards/ directory."
applyTo: "Cards/**/*.txt"
---

# Card DSL Specifications

## Source of Truth Rule
- Card definition files (`.txt` files inside `Cards/Cards/`, `Cards/OpponentCards/`, `Cards/Tokens/`) are the **source of truth** for game balance and abilities.
- If test assertions conflict with card definitions, card files are assumed correct and tests must be adjusted (or clarification requested from user).

## Maintenance Rule
**All real parsing logic lives in `Game/scripts/CardLoader.gd`.** `Game/scripts/AbilityParser.gd` is dead/unused code - do not reference it.
Whenever an engine change adds/removes a supported `EffectType`, `Mode$`, keyword, condition, or cost syntax, **update this file in the same change**. This file must stay a reliable, current description of what `CardLoader.gd` actually parses - do not let it drift.

## Card File Format

Card files are parsed line-by-line as `Key:Value` pairs until the `CardText:` line (everything after is display text, and `CardText:` must be the **last** field - the parser has no other terminator for it).

```txt
Name:Stone Golem
ManaCost:2
Types:Creature Construct
Power:2
T:Mode$ WouldFight | Execute$ StoneGolemWeaken
SVar:StoneGolemWeaken$ Weaken | Affected$ Card.InFrontOfMe | TargetCondition$ Target.Power>Self.Power | Duration$ EndOfTurn
CardText:When I would fight a creature with more power than me, that creature first lose all power.
```

### Key Fields
- `Name`: Full card name.
- `Color`: Comma-separated (`Red`, `Blue`, `Green`, `Black`, `White`, `None`).
- `Rarity`: `Common`, `Uncommon`, `Rare`, `Mythic`.
- `Types`: Space-separated types (`Creature`, `Spell`, `Relic`, `Legendary`, `Token`) followed by subtypes (max 3), e.g. `Creature Construct`.
- `ManaCost`: Gold cost integer.
- `Power`: Integer (creatures).
- `Durability`: Integer - starting Relic durability. Any card with this set gets a universal `BeginningOfTurn` trigger (auto-attached, not written by the card author) that ticks it down by 1 **only while the card currently has the Relic type**, sacrificing it at 0.
- `Countdown`: Integer - starting Countdown charge count. Any card with this set gets a universal `BeginningOfTurn` trigger (auto-attached) that ticks it down by 1 whenever `Countdown > 0`. When it reaches 0, the engine fires a `CountdownZero` event (**while the card is still in play**, so a `T:Mode$ CountdownZero` ability on the same card can reference its own zone/location) and then sacrifices the card.

### Ability & Effect Line Prefixes
Each can appear multiple times (parsed as an array):
- `T`: Triggered ability. `T:Mode$ <Mode> | <conditions...> | Execute$ <SVarName>`
- `R`: Replacement effect. `R:Event$ <EffectTypeString> | <conditions...> | ReplaceWith$ <SVarName>`
- `A` / `AA`: Activated ability. `A:AB$ <EffectTypeString> | Cost$ <cost> | <targeting...>` (old format: `AA:$ <EffectTypeString> | Cost$ <cost> | ...`)
- `K`: Simple keyword string (e.g. `Elusive`, `Giant`, `fleeting`). No parameters - see Keywords section.
- `AC`: Additional cost to cast the card itself. `AC:$ <CostType> | ValidCard$ ... | Count N`
- `CC`: Casting condition (card can only be cast if met). `CC:$ <filter string>` (e.g. `YouCtrl+Grown-up`)
- `SVar`: Named effect definition referenced by `Execute$`/`ReplaceWith$`. `SVar:<Name>$ <EffectTypeString> | param1$ value1 | param2$ value2`

Multiple `Execute$` effects can be chained on one `T:` line with `&` (e.g. `Execute$ EffectA & EffectB`) - this creates one `TriggeredAbility` per effect.

### Syntax Rules
- Parameters within a line are separated by ` | `.
- Most parameters use `Key$ Value`; a few legacy ones use `Key ` (space, no `$`) - see Costs below.
- Consult `Game/scripts/EffectType.gd` for the authoritative enum/string list, and `Game/scripts/CardLoader.gd` for how each prefix is actually parsed.

## Triggered Abilities (`T:`)

`Mode$` values (maps to `TriggeredAbility.GameEventType` via `TriggerType`):

| Mode$ | Fires when |
|---|---|
| `CardEnters` | Any card enters a battlefield zone (filter with `ValidCard$`, `Origin$`, `Destination$`) |
| `CardPlayed` | A card is played from hand |
| `StartAttack` | A card attacks (moves into a combat zone) |
| `ChangedZone` | Any zone change (use `Origin$`/`Destination$` to filter) |
| `Phase` | Turn phase boundary - requires `Phase$ BeginningOfTurn` or `Phase$ EndOfTurn` |
| `Strikes` | The card deals a combat strike |
| `CardDies` | A card moves from battlefield to graveyard |
| `CountdownZero` | This card's own `Countdown` counter just reached 0 (fires before it's sacrificed) |

Common trigger conditions (all optional):
- `ValidCard$` - filter string (see Filter Syntax below); `Card.Self` restricts to the card's own copy.
- `Origin$` / `Destination$` - zone filter strings (`Battlefield`, `Hand`, `Graveyard`, `Deck`, `Combat`) for zone-change triggers.
- `TriggerZones$` - which zones the ability is "live" in (defaults to `Battlefield`, i.e. battlefield + combat zones).
- `Phase$` - `BeginningOfTurn` or `EndOfTurn` (only for `Mode$ Phase`).
- `Condition$` - an extra boolean check, evaluated by `AbilityManager.evaluateCondition()`. Format: `Self.<Property>+<Timing>`, e.g.:
  - `Self.Attacked+ThisTurn`
  - `Self.IsType+Relic` (or `Creature`/`Spell`/`Legendary`/`Token`)
  - `Self.HasCountdown+Active` (true while `Countdown > 0` - used internally by the universal Countdown trigger; `Timing` is unused filler, kept only for format consistency)
  - Unknown `Property`/`Target` values are rejected with a warning - there is no generic "compare two different cards" condition on this branch.
- `Execute$` - the `SVar` name whose effect runs when the trigger fires.

## Replacement Effects (`R:`)

`R:Event$ <EffectTypeString> | <conditions> | ReplaceWith$ <SVarName>`
- `Event$` must be a valid `EffectType` string (e.g. `Death`) - this is the event being intercepted, not a `Mode$` value.
- `CreateToken` events use an in-place parameter modifier (`ReplaceTokenEffect`); every other event is a full substitution - the original event is cancelled and the `ReplaceWith$` SVar chain runs instead (`ReplaceEventEffect`).
- `ActiveZones$` restricts when the replacement is live (default `Any`).
- `ValidCard$` / `ValidToken$` further restrict what the replacement applies to.

## Activated Abilities (`A:` / `AA:`)

`A:AB$ <EffectTypeString> | Cost$ <cost string> | ValidCards$ <filter> | <effect params...>`

Repeated `Cost$` fields on one activated ability are mutually exclusive payment options. The first is the base cost; later costs are alternatives. When an alternative cost is selected, effect parameters named `Alternative<Name>$` override the matching `<Name>$` parameter (for example, `AlternativeAmount$ 2` overrides `Amount$ 1`). If a sacrifice selection satisfies multiple branches, the later matching branch is preferred.

Cost string formats (new, preferred):
- `T` - tap self.
- `Sac<N:filter>` - sacrifice N cards matching `filter` (controller is injected automatically relative to the activating card).
- `SacHere<N:filter>` - sacrifice N cards matching `filter` from either side's combat zone at this card's location.
- `Might>N` in a card filter - match creatures with power strictly greater than N (for example `Might>3` matches power 4+).
- Space-separated to combine, e.g. `T Sac<1:Card.Creature>`.

Old cost format (still parsed, `+`-separated): `Sac.Self`, `Pay.N`, `Tap.Self`.

- `ValidCards$` - targeting filter for the ability's effect (stored in `targeting_requirements`, not `effect_parameters`).
- `Activator$ Any` - allow the current player to activate an opponent-controlled card through the current player interface. It does not add opponent-AI activation behavior.
- Fields such as `KW$`, `Duration$`, `Amount$`, `NumCards$`, and `NumTarget$` are parsed into `effect_parameters` by `CardLoader.gd`.
- An alternative branch can override any matching effect parameter with `Alternative<Name>$`, e.g. `Amount$ 1 | AlternativeAmount$ 2`.

## Additional Costs (`AC:`) and Casting Conditions (`CC:`)

- `AC:$ SacrificePermanent | ValidCard$ <filter> | ValidCardAlt$ <filter> | Count N | AddReduction N` - pay by sacrificing a permanent instead of/alongside gold.
- `AC:$ Replace | ...` - the "Replace" alternative-casting mechanic (see `CardPaymentManager.gd`).
- `CC:$ <filter string>` - the card cannot be cast at all unless a card in play matches this filter (e.g. `YouCtrl+Grown-up`).

## Effects (`SVar:` target of `Execute$` / `ReplaceWith$`)

`SVar:<Name>$ <EffectTypeString> | param1$ value1 | param2$ value2`

### Implemented effect types (valid as `Execute$`/`ReplaceWith$`/`AB$` targets)
`DealDamage`, `Pump`, `Destroy`, `Draw`, `CreateToken`, `CreateCard`, `Cast`, `CreateDelayedEffect`, `AddType`, `AddKeyword` (alias `PumpAll`), `MoveCard`, `SwitchPositions`, `Sacrifice`, `RemoveCardFromPlay`, `Draft`, `AddGold`, `Recycle`, `ReduceCost`, `RaiseCountdown`.

`RelicDurabilityTick` and `CountdownTick` exist but are **auto-attached by the engine** (via `Durability:`/`Countdown:` fields) - never write these as `Execute$` targets yourself.

### Declared but NOT implemented (will `push_error` "Unknown effect type" if used)
`Bounce`, `Exile`, `Mill`, `Discard`, `Search`, `Shuffle`, `Death` (only usable as an `R:Event$` target, never as `Execute$`). Flag these to the user if a card design needs one - it requires new engine work first.

### Common effect parameters
- `Affected$` - resolves a pre-selected set of cards instead of the normal targeting pipeline. Supported values include `Card.Remembered` and `Card.PlayerCreaturesAtSourceLocation` (`Destroy` only; player-controlled creatures in the source card's combat location).
- `ValidTargets$` - targeting filter string requiring player/AI target selection.
- `Targets$` - (internal) pre-resolved target array; not written by card authors.
- `Duration$` - `Permanent`, `EndOfTurn`, or `WhileSourceInPlay`.
- `Choice$` - `Random` (default) or `Player`.
- `NumCard$` / `Amount$` / `NumDamage$` / `PowerBonus$` - numeric parameters; most accept either a literal int or the formula string `Card.Remembered.Power`.
- `subAbility$` / `followUp$` / `ifPaid$` - chain another SVar effect after this one resolves (aliases of the same mechanism).
- `alternativeResolve$` - run a different SVar instead if this effect's `can_execute()` check fails (e.g. no valid targets).

## Filter / Criteria Syntax (`ValidCard$`, `ValidTargets$`, etc.)

AND via `+`, OR via `/`, e.g. `Creature+YouCtrl+NonToken/Creature+Grown-up`.

Supported tokens: `Card` (always true), `Creature`/`Instant`/`Spell`/`Sorcery` (type checks), `YouCtrl`/`OppCtrl`, `Token`/`NonToken`, `HasReplace`, `Cost.N`. Any other bare token is treated as a subtype check (e.g. `Goblin`, `Grown-up`).

## Keywords (`K:`)

Implemented in `Shared/scripts/Keywords/KeywordRegistry.gd`: `Corrupted`, `Elusive`, `fleeting`, `Recycle`. `Giant` is checked directly via `CardData.get_combat_size()`, not through the keyword registry.
`Elusive` is detected from `CardText` substring matching rather than an explicit `K:` line (for backward compatibility) - new keywords should prefer an explicit `K:` entry.

## Known Engine Gaps (confirm before relying on these in a new card)
- No generic "compare property between two different cards" condition (e.g. "if that creature's power is higher than mine") exists in `Condition$` on this branch.
- Location scoping currently supports combat zones only. Cards in the shared `BATTLEFIELD_PLAYER` zone have no location assignment and are not included.
- `Bounce`/`Exile`/`Mill`/`Discard`/`Search`/`Shuffle` effect types are unimplemented stubs.
- `Activator$ Any` permits player-side activation of opponent-controlled cards, but does not add opponent-AI activation behavior.

