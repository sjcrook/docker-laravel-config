---
description: "Create or update the technical spec in docs/technical-spec.md, derived from docs/functional-spec.md"
agent: agent
tools: [read, edit, search]
---
Read [docs/functional-spec.md](../../docs/functional-spec.md). Interview the developer for anything missing, then write/update `docs/technical-spec.md` following its existing template. If the project has a UI, also ask about the frontend framework and tooling, and write/update `.github/instructions/frontend.instructions.md` to match (conventions plus a correct `applyTo` glob for the chosen stack) — this is the one exception to only touching the spec. Do not touch `docs/functional-spec.md`, `docs/tasks.md`, or `docs/handoff.md`.
