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
