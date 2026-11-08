---
name: recover-handoff
description: "Use when the user requests /recover-handoff, recovery after an interrupted session, or a handoff without the previous conversation. Reviews saved evidence and updates handoff/task status without implementation or shell commands."
---

# Recover an Interrupted Session

Before anything else, use the editing tool to write the exact text
`handoff-writer` (no trailing newline) to `.cline/.active-role`, creating the
directory if needed. This selects the existing no-shell handoff role.

## Preconditions
- The active implementation request and any autonomous worker must be stopped.
- Check whether `.github/auto-continue-enabled` exists. If it does, stop and ask
  the user to disable auto-continue and confirm the worker is stopped before
  running this workflow again. Do not remove the flag yourself.

## Review saved evidence
1. Read `AGENTS.md`, `docs/functional-spec.md`, `docs/technical-spec.md`,
   `docs/tasks.md`, and `docs/handoff.md`. Read
   `.ai-session/auto-continue.log` if available, using targeted sections around
   the interruption rather than loading the entire log.
2. Use available read-only tools to inspect relevant changed files and Git
   changes if those tools provide access. Do not run shell commands or tests.
   Do not assume the previous conversation is available.
3. Distinguish confirmed changes, recorded test results, failed or rejected
   operations, and unknowns. A rejected command batch did not run; earlier calls
   may have run. An old passing result does not prove the current files pass.
   Task labels, file changes, and successful process exit alone do not establish
   completion. If evidence is missing or inaccessible, state that explicitly.

## Write the recovery handoff
- Update `docs/handoff.md` using its existing sections: State / Decisions since
  last session / Open questions / Blockers / Next.
- Preserve unresolved questions, unrelated blockers, and known forward task
  dependencies. Include the affected task, last confirmed progress, uncertainties,
  and specific verification or implementation needed next (1-3 tasks).
- Update only status cells in `docs/tasks.md`, and only when evidence supports
  the change. Mark Done only when implementation and passing acceptance tests
  for the current state are verified. Interruption or missing evidence alone is
  not a new task blocker; leave unfinished work In Progress unless a real blocker
  is established. Record real blockers on the affected task row, not only in the
  handoff, and do not clear unrelated blockers.
- Apart from the initial role marker, edit only the handoff and task status cells.
  Do not edit source, execute commands, change operator policy, or restart
  automation. Report what was updated and any verification still needed.
