# GitHub Copilot Instructions

## General Guidelines

- **Concise Explanations**: Provide only essential information to understand the subject. Skip narration of actions being performed.
- **No Documentation Files**: Do not create markdown files to document changes or summarize work unless explicitly requested.
- **Current Checkout Is Authoritative**: Before editing, inspect the current files and branch state relevant to the task. After a branch switch, pull, or rebase, never assume code described in earlier chat history is present in the checkout.
- **Preserve Existing Work**: Treat staged and unstaged changes as user work. Do not revert or overwrite them unless explicitly asked.
- **Preserve Godot Version**: Never change the Godot version in `project.godot` during feature work, merges, or cleanup. Preserve the current checkout's version exactly unless the user explicitly requests a version change.
- **Test Execution Requires Permission**: Do not launch the game, run the Test Manager, or execute test suites unless the user explicitly permits it. A request to add or fix tests is not permission to run them. Static checks and diff checks are okay.

## Conflict Resolution

When encountering contradictions between different parts of the codebase:

1. **Card Files are Source of Truth**: When test assertions conflict with card definitions (e.g., `.txt` files in `Cards/` directory), assume the **card file is correct** and the test is wrong.

2. **Always Ask**: When two things contradict each other, **ask the user which is correct** before making changes. Do not assume which side is right.

3. **Examples**:
   - If a test expects `AddReduction 2` but the card file has `AddReduction 1`, ask which value is correct
   - If test logic conflicts with game logic, ask for clarification

## Specialist Agent Delegation

- For substantive work that clearly matches a configured specialist agent, invoke that agent even when the user has not explicitly requested delegation.
- Use **Card Designer** for card definitions and balance, **Card Game QA** for test creation or test-focused debugging, and **Engine Dev** for game mechanics, parsers, effects, and core GDScript.
- For work spanning multiple specialties, invoke each relevant agent sequentially with a narrowly scoped task; avoid delegation for simple questions or trivial edits that do not benefit from specialist review.
- The primary assistant remains responsible for checking the current worktree, integrating agent changes, resolving conflicts, and validating the final result. Do not run game or test suites unless the user permits it.
- Before delegation, provide the specialist with the current task scope and relevant current-checkout context; do not rely on stale conversation summaries or old branch state.

## Code Changes

- Use `multi_replace_string_in_file` when making multiple independent edits for efficiency
- Include 3-5 lines of context before and after changes in `replace_string_in_file`
- Do not announce which tool is being used
