---
name: functional-spec
description: Create or update the functional spec in docs/functional-spec.md from a feature description. Use when the user says "/functional-spec" or asks to write or update the functional spec.
---

Before anything else, write the exact text `none` (no trailing newline) to
`.cline/.active-role`, creating the `.cline` directory if needed, so this
unrestricted workflow doesn't inherit a planner/handoff-writer restriction a
previous task may have left behind.

Follow the Readiness and Steering contract in `AGENTS.md`; await role selection
and edit results separately and ask before starting another workflow.

Read `.github/instructions/planning.instructions.md` and follow its Functional
specification section. Interview for missing behavior, then update the existing
`docs/functional-spec.md`, preserving unrelated requirements and following its
existing template. Do not touch `docs/technical-spec.md`, `docs/tasks.md`,
`docs/handoff.md`, or `docs/planning/`.
