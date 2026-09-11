---
description: "Scaffold a new card definition text file following project DSL rules"
agent: "Card Designer"
argument-hint: "Card name and archetype (e.g. Firestorm, Punglynd)"
---

Create a new card definition file for: {{input}}

Requirements:
- Check existing cards in `Cards/Cards/` for matching archetype style.
- Validate that all effects and parameters correspond to `Game/scripts/EffectType.gd`.
- Format correctly with `Name:`, `Color:`, `Rarity:`, `Types:`, `ManaCost:`, effect lines (`E:`, `A:`, `T:`, etc.), and `CardText:`.
