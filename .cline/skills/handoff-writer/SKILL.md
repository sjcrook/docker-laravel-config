---
name: handoff-writer
description: Use at the end of a session to write docs/handoff.md, or when asked to summarize session state for the next session. Does not write implementation code or run shell commands.
---

# Handoff Writer Role

Before anything else, write the exact text `handoff-writer` (no trailing
newline) to `.cline/.active-role`, creating the `.cline` directory if needed,
so the project's `PreToolUse` hook enforces this role's restrictions for the
rest of this task. This also clears any role a previous task may have left
behind.

You are the handoff writer. Your job is to leave an accurate snapshot for the
next session.

## Constraints
- DO NOT edit source code.
- DO NOT run shell commands — this role has no execute access, enforced by
  the project's `PreToolUse` hook, not just this instruction.
- DO NOT invent progress that isn't verifiable from git history or
  `docs/tasks.md`.
- ONLY edit `docs/handoff.md`, and status cells in `docs/tasks.md`.

## Approach
Read `.github/instructions/planning.instructions.md` and follow its Handoff
section. Refresh "Next" from current eligible tasks and planning approval, not
just conversation memory; never select Superseded work or approve/update planning
snapshots.

1. Review what changed this session (diffs, test results, `docs/tasks.md`
   state).
2. Overwrite `docs/handoff.md` using its template: State / Decisions since
   last session / Open questions / Blockers / Next (1-3 tasks). Carry forward
   any unresolved, non-blocking "Open questions" unchanged — don't drop them
   just because the file gets overwritten.
3. Reflect any completed or blocked tasks in `docs/tasks.md`. If an open
   question is actually blocking one task, mark that task
   `⛔ Blocked · <question>` instead of leaving it only in "Open questions".
   If it blocks ALL remaining work, also mark the next task to be worked
   `⛔ Blocked · <question>` — noting it only in "Blockers" below will not
   trigger the lifecycle hooks' notification, since detection only scans
   task rows in `docs/tasks.md`.
4. If a task was left paused on a forward test dependency
   (`🔄 In Progress · <date> (depends on T0XX)` — see `docs/tasks.md`'s
   legend), list both the paused task and the task it depends on together in
   "Next", e.g. "S02/T003 (resume after S02/T005)", so the pairing isn't
   lost.

## Output Format
An updated `docs/handoff.md` and, if needed, `docs/tasks.md`.
