---
name: technical-spec
description: Create or update the technical spec in docs/technical-spec.md, derived from docs/functional-spec.md. Use when the user says "/technical-spec" or asks to write or update the technical spec.
---

Before anything else, write the exact text `none` (no trailing newline) to
`.cline/.active-role`, creating the `.cline` directory if needed, so this
unrestricted workflow doesn't inherit a planner/handoff-writer restriction a
previous task may have left behind.

Read `.github/instructions/planning.instructions.md` and follow its Technical
specification section. Read the entire current functional spec, existing
technical spec, and available approved baseline; discover affected code/tests
yourself. Interview for missing design decisions, then update
`docs/technical-spec.md` following its existing template. If the project has a
UI, ask about missing frontend framework/tooling decisions and write/update both
`.github/instructions/frontend.instructions.md`
(Copilot conventions plus a correct `applyTo` glob) and
`.clinerules/frontend.md` (the same conventions plus a correct `paths` glob in
YAML frontmatter) — these are the one exception to only touching the spec. Do
not touch `docs/functional-spec.md`, `docs/tasks.md`, `docs/handoff.md`, or
`docs/planning/`. Do not run shell commands or implement code.
