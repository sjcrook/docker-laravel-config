---
name: tasks
description: Break down docs/functional-spec.md and docs/technical-spec.md into sprint tasks and update docs/tasks.md. Use when the user says "/tasks" or asks to plan or re-plan sprint tasks. Does not write implementation code or run shell commands.
---

Before anything else, write the exact text `planner` (no trailing newline) to
`.cline/.active-role`, creating the `.cline` directory if needed, so the
project's `PreToolUse` hook enforces the planner role's restrictions for the
rest of this task (no shell commands). This also clears any role a previous
task may have left behind.

Read `docs/functional-spec.md`, `docs/technical-spec.md`, and the current
`docs/tasks.md`. Add or revise tasks so each one is small and independently
testable (TDD-sized) following an Agile, sprint-based methodology, as rows in
the task table with sequential `S<2-digit>`/`T<3-digit>` IDs — each task
should have exactly one test that can pass on its own, without needing a
later task's code to exist. If a forward dependency is genuinely unavoidable,
say so explicitly in the earlier task's description (e.g. "depends on T0XX
for its test to pass") rather than leaving it implicit. Preserve existing
`✅ Done`, `🔄 In Progress`, and `⛔ Blocked` rows as-is.

## Constraints
- DO NOT edit source code — planning only.
- DO NOT run shell commands — this role has no execute access, enforced by
  the project's `PreToolUse` hook, not just this instruction.
- DO NOT mark a task `✅ Done` — only the implementer does that.
- ONLY edit `docs/tasks.md` (and `docs/functional-spec.md`/`docs/technical-spec.md`
  if clarifying scope).
