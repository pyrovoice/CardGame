# GitHub Copilot Instructions

## General Guidelines

- **Concise Explanations**: Provide only essential information to understand the subject. Skip narration of actions being performed.
- **No Documentation Files**: Do not create markdown files to document changes or summarize work unless explicitly requested.

## Conflict Resolution

When encountering contradictions between different parts of the codebase:

1. **Card Files are Source of Truth**: When test assertions conflict with card definitions (e.g., `.txt` files in `Cards/` directory), assume the **card file is correct** and the test is wrong.

2. **Always Ask**: When two things contradict each other, **ask the user which is correct** before making changes. Do not assume which side is right.

3. **Examples**:
   - If a test expects `AddReduction 2` but the card file has `AddReduction 1`, ask which value is correct
   - If test logic conflicts with game logic, ask for clarification

## Code Changes

- Use `multi_replace_string_in_file` when making multiple independent edits for efficiency
- Include 3-5 lines of context before and after changes in `replace_string_in_file`
- Do not announce which tool is being used

## Controller Test Verification

- After completing a feature or code modification, run the full controller suite from the project root: `python3 Test/run_tests.py --godot /path/to/godot`. Alternatively, set `GODOT_BIN` or have `godot` on `PATH`. See `README.txt` for setup, single-test selection and logging.
- Examine assertion failures, timeouts and Godot errors; a passing assertion alone does not mean the run was clean. Report the results and any existing failures or blockers explicitly.
- Assess whether each failing test reflects an unintended regression or a deliberate behavior change. Do not silently change tests to make them pass; follow the conflict-resolution guidance above and ask the user when requirements or conflicting expectations are unclear.
- The suite currently includes an intentionally failing test to verify failure reporting. Identify it separately from unexpected failures; do not treat it or other existing errors as a clean run.
