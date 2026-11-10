---
name: tasks
description: Break down docs/functional-spec.md and docs/technical-spec.md into sprint tasks and update docs/tasks.md. Use when the user says "/tasks" or asks to plan or re-plan sprint tasks. Does not write implementation code or run shell commands.
---

Before anything else, write the exact text `planner` (no trailing newline) to
`.cline/.active-role`, creating the `.cline` directory if needed, so the
project's `PreToolUse` hook enforces the planner role's restrictions for the
rest of this task (no shell commands). This also clears any role a previous
task may have left behind.

Use a native file-editing tool for this role marker, including directory
creation if needed; never use a shell command to initialize the role.
Wait for its result before any other tool call; read back an already-correct
marker if the editor reports a no-op. Follow the Readiness and Steering
contract in `AGENTS.md` before document edits.

## Tool use
Use only native file-reading, searching, and editing tools throughout planning,
including setup, repository inspection, spec updates, and snapshot creation.
Do not invoke `run_commands` or `execute_command`, even for `pwd`, `git status`,
directory creation, file copying, or verification. After writing approved
snapshots, re-read them with file tools and compare their contents with the
source documents before setting Approved last. Do not run `check-planning.sh`
from this role; the implementer runs that check before implementation.
If a required file operation is unavailable, report the limitation and stop
rather than attempting shell execution or bypassing the hook.

Read `.github/instructions/planning.instructions.md` and follow its Task planning
and approval section, including initial/change planning, code inspection,
persistent reconciliation, and explicit approval. Read available planning
review/snapshots, `docs/functional-spec.md`, `docs/technical-spec.md`, and the current
`docs/tasks.md`. Plan the full backlog, not just the handoff's "Next" tasks;
implementation session limits do not apply. Add or revise tasks so each one
has a concrete description and testable acceptance criteria and is small and
independently testable (TDD-sized) following an Agile, sprint-based methodology,
as rows in the task table with sequential `S<2-digit>`/`T<3-digit>` IDs — each task
should have exactly one test that can pass on its own, without needing a
later task's code to exist. If a forward dependency is genuinely unavoidable,
say so explicitly in the earlier task's description (e.g. "depends on T0XX
for its test to pass") rather than leaving it implicit.

Fill blank template placeholders in place using the definition in
`docs/tasks.md`, retaining their IDs, then append as many sequential tasks and
sprints as needed. The three template rows are not a task limit. Reset only
a placeholder blocked solely for missing description/acceptance criteria to
`🔲 Todo` once those details are supplied. Preserve genuine existing
`✅ Done`, `🔄 In Progress`, and `⛔ Blocked` rows as-is, except explicitly
approved supersessions of unfinished work under the shared workflow.

Before finishing, check that every requirement in both specifications is
covered by a task or an explicit unresolved blocker, and no placeholder remains
blank. Report any stale handoff that needs a separate update; do not edit it.

Persist the proposal/reconciliation in `docs/planning/review.md` and ask for
explicit developer approval. Keep review Pending and previous snapshots unchanged
until approval; save current specs/tasks verbatim and set Approved last only
after approval, following the shared workflow.

## Constraints
- DO NOT edit source code — planning only.
- DO NOT run shell commands — this role has no execute access, enforced by
  the project's `PreToolUse` hook, not just this instruction.
- DO NOT mark a task `✅ Done` — only the implementer does that.
- ONLY edit `docs/tasks.md` and `docs/planning/` (and `docs/functional-spec.md`/`docs/technical-spec.md`
  if clarifying scope).
  Role selection and cleanup of `.cline/.active-role` are also permitted.

## Role cleanup
When finishing or stopping this workflow, including an unmet precondition, use
a native file-editing tool to write the exact text `none` (no trailing newline)
to `.cline/.active-role` as the final file operation. Do not run shell commands after cleanup
as part of this workflow. Do not select `implementer` or restore a previous role.
This marker update is allowed in addition to the document-edit scope above.
If cleanup fails, report the failure rather than claiming the role was released.
