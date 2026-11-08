---
description: "Prepare a specified task for restarting after operator command approval; does not implement or launch automation"
agent: handoff-writer
---

Prepare the task ID supplied with this request for resuming after a permission
denial. Example invocation: `/prepare-resume T032`.

## Preconditions
1. Require exactly one task ID matching a unique row in `docs/tasks.md`. If it
   is missing, ambiguous, or unknown, ask for clarification and do not change files.
2. Check `.github/auto-continue-enabled`. If present, ask the user to disable
   auto-continue and stop the worker, then invoke this workflow again. Do not
   remove the flag yourself.
3. Require the user's confirmation that all implementation requests and workers
   are stopped. Flag absence alone does not prove this. Do not run shell commands
   to check processes; if confirmation is missing, ask before changing task state.

## Verify the permission and saved state
Read `.github/instructions/planning.instructions.md`, planning review, and
approved snapshots. If planning approval is missing, Pending, or stale against
current specs/task scope, or the specified task is Superseded, report
`Not ready to resume <task_id>` and request `/tasks`; do not reactivate it or
modify planning approval.

1. Read `AGENTS.md`, the specifications, `docs/tasks.md`, and `docs/handoff.md`.
   Read `command-exceptions/command-exceptions.conf` using tools in the current
   workspace. If the user has not established this is the intended container
   workspace, ask them to run this workflow there; do not claim host reads prove
   container visibility.
2. Report the named exceptions actually read. Validate one name per line:
   `allow-recursive-delete`, `allow-git-push`, or `allow-sudo`. Blank lines,
   full-line comments, surrounding whitespace, and duplicate names are allowed.
   Missing policy grants nothing. Invalid, unreadable, symlinked, or otherwise
   unusable policy does not establish approval; report the problem.
3. Review targeted sections of `.ai-session/auto-continue.log` and the specified
   task's handoff to identify the relevant rejection. For an interactive session,
   request the rejection details if they are not saved. Logs may contain multiple
   sessions and do not necessarily identify a task. Do not associate a denial
   with the task solely because it is the latest entry. If the task, rejected
   operation, or required permission is unclear, ask for clarification.
4. Map `rm -rf` to `allow-recursive-delete`, `git push` to `allow-git-push`, and
   `sudo` to `allow-sudo`. Every restricted class in the rejected batch needs
   approval. A diagnostic may report only the first unapproved rule; if complete
   batch information is unavailable, report that uncertainty and obtain the
   missing details before declaring readiness. Role denials and non-permission
   errors are not resolved by these exceptions.
5. Inspect relevant files and Git changes with available read-only tools, plus
   recorded results. Do not execute the rejected operation, shell commands, or
   tests to check approval. A rejected batch did not run; earlier calls may have.
   Distinguish confirmed progress from unknowns and validation still needed.
   Passing logs alone do not prove the current files pass.

## Prepare, do not implement
- Change only the specified task's status cell and `docs/handoff.md`.
- If approval covers the established denial and no other blocker on that task
  remains, change Blocked to In Progress with today's date and a short note.
  An already In Progress task stays unfinished; never change a Done task back
  without clarification. Preserve unrelated task statuses, blockers, questions,
  and dependencies. Do not clear the entire handoff's Blockers section.
- Update the handoff's existing sections with visible approvals, confirmed
  progress, uncertainties, and a concrete restart plan. Put the specified task
  under Next, including remaining implementation and acceptance validation.
- If permission or another task blocker is unresolved, retain its blocked status
  and explain what remains. Do not invent a blocker merely because tests need
  rerunning.
- Do not edit source, policy, enforcement, or enable files; do not mark Done,
  implement, run tests, or start automation.
- Report either `Ready to resume <task_id>` (permission issue resolved, not
  implementation verified) or `Not ready to resume <task_id>` with reasons.
  Separately report any other Blocked task rows: this kit will not auto-continue
  while any remain, even if the specified task is ready.
