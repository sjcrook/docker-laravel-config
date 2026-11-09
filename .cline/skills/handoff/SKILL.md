---
name: handoff
description: Generate or update docs/handoff.md at the end of a session. Use when the user says "/handoff" or asks to write a handoff or summarize session state for the next session. Does not write implementation code or run shell commands.
---

Before anything else, use a native file-editing tool to write the exact text `handoff-writer` (no trailing
newline) to `.cline/.active-role`, creating the `.cline` directory if needed,
so the project's `PreToolUse` hook enforces the handoff-writer role's
restrictions for the rest of this task (no shell commands). This also clears
any role a previous task may have left behind.

Read `.github/instructions/planning.instructions.md` and follow its Handoff
section. Refresh "Next" from current eligible tasks and planning approval; never
select Superseded work or approve/update planning snapshots.

Summarize this session and update `docs/handoff.md` using its template
(State / Decisions since last session / Open questions / Blockers / Next),
carrying forward unresolved non-blocking "Open questions" unchanged. Update
the status of any `docs/tasks.md` rows confirmed complete this session to
`✅ Done · <date>`. Mark `⛔ Blocked · <reason>` on any task that could not be
finished, including one stuck on an unanswered blocking question — if that
question blocks all remaining work, not just one task, still mark a task row
Blocked (not only this file) so the lifecycle hooks' detection fires. If a
task is paused only on a forward test dependency (not a true blocker), leave
it `🔄 In Progress · <date> (depends on T0XX)` and list the pair together
under "Next". Only report progress that is verifiable from the diff/tests,
not assumed.

## Constraints
- DO NOT edit source code.
- DO NOT run shell commands — this role has no execute access, enforced by
  the project's `PreToolUse` hook, not just this instruction.
- DO NOT invent progress that isn't verifiable from git history or
  `docs/tasks.md`.
- ONLY edit `docs/handoff.md`, and status cells in `docs/tasks.md`.
  Role selection and cleanup of `.cline/.active-role` are also permitted.

## Role cleanup
When finishing or stopping this workflow, including an unmet precondition, use
a native file-editing tool to write the exact text `none` (no trailing newline)
to `.cline/.active-role` as the final file operation. Do not run shell commands after cleanup
as part of this workflow. Do not select `implementer` or restore a previous role.
This marker update is allowed in addition to the document-edit scope above.
If cleanup fails, report the failure rather than claiming the role was released.
