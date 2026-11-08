---
description: "Break down docs/functional-spec.md and docs/technical-spec.md into sprint tasks and update docs/tasks.md"
agent: planner
---
Read [the shared planning workflow](../instructions/planning.instructions.md) and follow its Task planning and approval section for initial planning, code-aware change planning, reconciliation, and explicit approval. Read [docs/functional-spec.md](../../docs/functional-spec.md), [docs/technical-spec.md](../../docs/technical-spec.md), the current [docs/tasks.md](../../docs/tasks.md), and available planning review/snapshots. Plan the full backlog, not just the handoff's "Next" tasks; implementation session limits do not apply.

Add or revise tasks so each one has a concrete description and testable acceptance criteria and is small and independently testable (TDD-sized), following an Agile, sprint-based methodology. Fill the blank template placeholders in place, retaining their `S<2-digit>`/`T<3-digit>` IDs, then append as many sequential tasks and sprints as needed. The three template rows are not a task limit. Follow the placeholder definition in docs/tasks.md: reset only a placeholder blocked solely for missing description/acceptance criteria to `🔲 Todo` once those details are supplied. Preserve genuine existing `✅ Done`, `🔄 In Progress`, and `⛔ Blocked` rows as-is, except explicitly approved supersessions of unfinished work under the shared workflow.

If a task's test can only pass once a later task exists, say so explicitly in its description rather than leaving it implicit. Before finishing, check that every requirement in both specifications is covered by a task or an explicit unresolved blocker, and no placeholder remains blank. Report any stale handoff that needs a separate update; do not implement code or mark tasks Done.

Persist the proposal and reconciliation in `docs/planning/review.md`. Ask for explicit developer approval; leave it Pending until approval, then save verbatim approved snapshots and set Approved last. Only edit `docs/tasks.md` and `docs/planning/` (or the specs when clarifying scope); never implement or update the handoff.
