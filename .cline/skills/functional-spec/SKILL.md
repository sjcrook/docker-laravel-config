---
name: functional-spec
description: Create or update the functional spec in docs/functional-spec.md from a feature description. Use when the user says "/functional-spec" or asks to write or update the functional spec.
---

Before anything else, write the exact text `none` (no trailing newline) to
`.cline/.active-role`, creating the `.cline` directory if needed, so this
unrestricted workflow doesn't inherit a planner/handoff-writer restriction a
previous task may have left behind.

Interview the developer for anything missing, then write/update
`docs/functional-spec.md` following its existing template. Do not touch
`docs/technical-spec.md`, `docs/tasks.md`, or `docs/handoff.md`.
