---
description: "Read explicitly for specification, task planning, planning approval, and handoff workflows in Copilot or Cline."
---
# Specification and planning workflow

Before specification or planning edits, check `.github/auto-continue-enabled`.
If present, ask the developer to disable auto-continue and stop its worker before
proceeding. Do not remove the flag or stop processes yourself. Confirm no
implementation request or worker is running before changing an existing plan;
do not race implementation or let approval restart automation before review and
handoff are finished.

## Functional specification
Read the existing `docs/functional-spec.md` before editing. With no feature description, ask what project to build if it is a blank template, or what to add/change if it is populated. Update the existing document, not a second specification.

Preserve unrelated requirements and acceptance examples. Replace or remove behavior explicitly superseded by the requested change; do not retain contradictory requirements. Ask when the intended scope is ambiguous. Confirm a wholesale scope replacement before deleting existing requirements. Interview for missing behavior and summarize additions, changes, and removals for review. Do not edit the planning baseline.

## Technical specification
Read the entire current functional spec, existing technical spec, and available approved snapshots in `docs/planning/`. Compare with the approved functional-spec snapshot when available; do not ask the developer to enumerate changed requirements or name implementation components.

Discover and read relevant source, tests, configuration, interfaces, and documentation using read/search tools. Update the existing technical spec for every affected functional requirement, including compatibility, error handling, data, and verification. Preserve unrelated design decisions. Ask about genuine design choices or contradictions, not code locations the agent can discover. If no approved baseline exists, explicitly say so and reconcile the full current functional spec against the design. Report requirement-to-design coverage and unresolved questions. Do not implement or edit the planning baseline.

## Task planning and approval
Read both complete current specs, `docs/tasks.md`, and `docs/planning/review.md`, plus all available approved snapshots. Use one `/tasks` workflow for initial and subsequent planning:

- Initial planning: only blank task placeholders exist. Create a full backlog covering both specs.
- Change planning: genuine tasks exist. Compare current specs against the last approved snapshots, identifying added, changed, and removed requirements. Inspect affected code, tests, help, and documentation to establish the implementation impact.
- Missing/incomplete baseline: explicitly report that no reliable previous spec revision is available. Reconcile the full current specs against tasks and available implementation evidence; do not invent a change history.

Before proposing any backlog changes, set `docs/planning/review.md` to `Status: Pending`. Keep previous approved snapshots unchanged while review is pending. Planning is full-backlog work: the three template rows are not a task limit. Account for every requirement in both specifications, including unchanged requirements the diff would miss.

### Requirement reconciliation
Compare each requirement and acceptance example with existing task descriptions and acceptance criteria, not just titles or statuses. A Done status is historical evidence, not proof of coverage for a changed requirement. Task coverage is not proof that the implementation works: cite inspected code/tests, or explicitly record missing evidence.

Identify missing, partial, and contradictory coverage, changed interfaces/error behavior, removed behavior, and formerly invalid inputs that are now valid. Plan implementation, tests, help, and documentation, including removal or replacement of obsolete tests.

Preserve completed task rows as history; append new Todo follow-up tasks with fresh sequential IDs and references to affected earlier IDs. Do not duplicate pending work whose acceptance criteria already cover the requirement. Preserve existing In Progress and genuinely Blocked work unless the developer explicitly approves its disposition.

For contradictory pending work, propose an explicit disposition in the review. On approval, mark obsolete Todo/In Progress/Blocked work `Superseded · replaced by T<id>` (or `Superseded · scope removed`), preserving its ID and description. Never mark unimplemented work Done. If disposition is unresolved, keep review Pending and record the conflict; implementation cannot resume.

Persist a reconciliation table in `docs/planning/review.md` and include it in the response:
`Requirement | Existing task IDs | Coverage or mismatch | New task IDs or blocker`
Use requirement IDs when available, otherwise spec sections/acceptance examples. Include removed requirements and implementation evidence. Do not claim "no changes needed" without this reconciliation. Report a stale handoff for a separate update; do not edit it.

### Explicit approval
Show the proposed backlog, reconciliation, unresolved blockers, and any proposed supersessions. Before asking for approval, provide clickable links to `docs/planning/review.md` and `docs/tasks.md`, using paths resolved against the current workspace (not the kit templates). Also include those links in the approval question's message so the developer can open the exact documents from the question itself. State which task IDs and dispositions are being approved. Ask the developer to approve this exact plan, request revisions, or leave it pending. Never infer approval from invoking `/tasks`, silence, or successful tests. If an interactive question tool is unavailable, request approval in chat with the same links and stop with review Pending.

On explicit approval only:
1. Re-read the current specs/tasks. If substantive content changed since the proposal, reconcile again and obtain approval of the revised plan.
2. Apply only the approved supersessions.
3. Copy the complete current documents verbatim, using file-editing tools, to `docs/planning/functional-spec.md`, `docs/planning/technical-spec.md`, and `docs/planning/tasks.md`. These are approved snapshots, not separately maintained specs. Do not edit the source specs to create snapshots. The approval check tolerates an optional final newline added by an editor, but no other spec content differences.
4. Record the developer's explicit approval and approved dispositions in `docs/planning/review.md`, then write `Status: Approved` last.

For a later approval in a new conversation, read the persisted proposal and current documents, present the exact current plan again, and obtain explicit approval. Declined/cancelled review remains Pending. Never advance the baseline merely because planning finished. Repeating `/tasks` may refresh evidence but must not duplicate tasks. Approval is required even if no task additions are needed.

Only the planner may write these snapshots or approval status. Commit `docs/planning/` with the project documents. Status-only implementation progress does not invalidate approval; changed specs, task IDs/order/descriptions, or review status do. The baseline records a reviewed plan, not verified implementation correctness.

## Handoff
Read current specs/tasks, existing handoff, and planning review/snapshots without requiring text after `/handoff`. Refresh "Next" from actual eligible task statuses, excluding Done, Blocked, and Superseded work, while preserving forward-dependency pairs. If review is Pending, missing, or stale against current specs/task scope, state that planning approval is required before implementation; do not present tasks as ready. Never approve a plan or modify snapshots from a handoff workflow.
