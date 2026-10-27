# Repository Working Rules

These rules apply to all work in this repository and must be followed before any code or configuration change.

## Branch policy — strict
- Never create, rename, or switch to a new Git branch unless the user explicitly gives permission first.
- Work only on the branch the user has selected. The current requested working branch is `feature/3d-companion-mvp-shell`.
- Do not create a branch “for safety”, experiments, or design work without asking and receiving explicit approval.
- If a task cannot be completed safely on the selected branch, stop and explain the limitation; do not create a branch.

## Change policy
- Inspect the actual current source and relevant build logs before editing.
- Follow the user-provided/source design references closely; do not invent UI layouts or treat a list of labels as a completed design match.
- Make the smallest change that satisfies the request. Preserve existing working chatbot behavior, persistence, APIs, theme colors, and unrelated screens.
- Do not refactor unrelated code or change scope without permission.
- Do not claim a build passed unless a real build result confirms it. If unable to build, state that clearly and provide the exact verification needed.
- Before any repository write, confirm the target repository, selected branch, file path, and current file SHA. Commit only to the selected branch.
- If requirements or source assets cannot be inspected, report the blocker rather than guessing.

## Current task
- Continue UI work on `feature/3d-companion-mvp-shell`.
- Compare Memory against the existing design images available in project context before changing its layout.
- Keep the current Memory data model and chatbot integration intact unless a separate functional fix is explicitly requested.
