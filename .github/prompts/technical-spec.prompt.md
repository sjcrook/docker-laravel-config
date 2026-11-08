---
description: "Create or update the technical spec in docs/technical-spec.md, derived from docs/functional-spec.md"
agent: agent
tools: [read, edit, search]
---
Read [the shared planning workflow](../instructions/planning.instructions.md), then follow its Technical specification section. Read the entire [docs/functional-spec.md](../../docs/functional-spec.md), existing technical spec, and available approved baseline; discover affected code/tests yourself. Interview for missing design decisions, then update `docs/technical-spec.md` following its existing template. If the project has a UI, ask about missing frontend framework/tooling decisions and write/update both `.github/instructions/frontend.instructions.md` (Copilot conventions plus a correct `applyTo` glob) and `.clinerules/frontend.md` (the same conventions plus a correct `paths` glob in YAML frontmatter) — these are the one exception to only touching the spec. Do not touch `docs/functional-spec.md`, `docs/tasks.md`, `docs/handoff.md`, or `docs/planning/`.
