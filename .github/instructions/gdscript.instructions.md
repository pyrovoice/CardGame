---
description: "Guidelines and coding conventions for Godot 4 GDScript in this card game project. Covers static typing, node life cycle, and context folders."
applyTo: "**/*.gd"
---

# GDScript Architecture Guidelines

## Workspace & Context Context
- When working on game mechanics, always refer to the `Game` and `Shared` folders (`Game/scripts/`, `Game/scenes/`, `Shared/scripts/`).
- Engine configurations and project-wide autoloads reside in `project.godot`.

## GDScript & Godot 4 Conventions
- **Explicit Typing**: Use static typing everywhere possible (`var card: CardData`, `func execute(action: GameAction) -> void:`).
- **Naming Conventions**:
  - `class_name` in PascalCase (e.g. `CardLoader`, `BaseTestManager`).
  - Functions and variables in `snake_case` or project-consistent camelCase where established (e.g., maintain local file consistency).
  - Enums in PascalCase or SCREAMING_SNAKE_CASE as defined in core types (e.g. `EffectType.Type`).
- **Memory & Node Lifecycle**:
  - Distinguish between `RefCounted` objects (e.g. `EffectType`, `CardData`) and `Node` / `Node3D` / `Control` instances (`queue_free()` when removing nodes).
  - Avoid creating dangling signals; disconnect or ensure node cleanup on destruction.
- **Queue and State Operations**:
  - Game actions should route through the proper queue resolution mechanisms (`ResolvableQueue.gd`, `AbilityManager.gd`).
  - Do not modify state directly across layers if a manager or queue event handles it.
