---
description: "Generate a test method in Test/ for a specific card or mechanic"
agent: "Card Game QA"
argument-hint: "Card name or ability to test"
---

Generate a test case in `Test/ControllerTestManager.gd` for: {{input}}

Requirements:
- Read the card's definition in `Cards/` as the single source of truth.
- Use `assert_test_*` assertion methods from `BaseTestManager.gd`.
- Simulate setup, action execution, and queue resolution cleanly.
