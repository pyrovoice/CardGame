---
description: "Rules and conventions for writing game tests, assertions, and harness interactions in Test/."
applyTo: "Test/**/*.gd"
---

# Card Game Testing Instructions

## Philosophy
- **Cards are Source of Truth**: When test assertions conflict with card definitions in `Cards/`, the card definition is considered correct. Ask the user if clarification is needed, but never silently downgrade a card definition to match a broken test.
- Tests inherit from `BaseTestManager.gd` or work within `TestGameRunner.gd`.

## Assertion Guidelines
- Use the custom assertion helpers provided in `BaseTestManager.gd`:
  - `assert_test(condition: bool, message: String)`
  - `assert_test_equal(actual, expected, message: String)`
  - `assert_test_not_null(value, message: String)`
  - `assert_test_null(value, message: String)`
  - `assert_test_true(condition: bool, message: String)`
  - `assert_test_false(condition: bool, message: String)`
- Do not use native GDScript `assert()` for test harness assertions because native asserts halt the execution rather than recording failure metrics in `test_results`.

## Testing Best Practices
- Initialize state cleanly before each scenario.
- Test both sides of triggered/replacement interactions through `ResolvableQueue`.
- Verify zone transitions (e.g., Hand -> Battlefield -> Graveyard).
