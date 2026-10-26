# Project Guidelines

## Session Start
- Read `docs/functional-spec.md`, `docs/technical-spec.md`, `docs/tasks.md`, and `docs/handoff.md` before doing anything else (a `SessionStart`-equivalent check also happens via the Stop hook from the previous session).
- Work only the task(s) listed under "Next" in `docs/handoff.md` — don't scope-creep into later sprints. If `docs/handoff.md` is still the unedited template (e.g. `State` still reads `{What exists right now...}`), this is the first session: start from the first `🔲 Todo` row in `docs/tasks.md` instead.
- If the task you'd pick up is already `🔄 In Progress`, don't assume the previous session finished or even safely started it — check `git status`/`git diff` and run the test suite first to find the real state before resuming or restarting it.

## Methodology
- Agile, sprint-based: work exactly one task from `docs/tasks.md` at a time, in the order sprints/tasks are listed unless told otherwise. The moment you start one, set its status to `🔄 In Progress · <today's date> (<short note of what you're about to do>)` — this is the only durable breadcrumb if the session is interrupted before `docs/handoff.md` gets updated.
- Test-driven: write a failing test before implementation code, for every task, and do not move on to the next task until that task's own test passes. Set a task's status to `✅ Done · <today's date>` only when its test passes.
- Forward test dependency: if a task's test can only pass once a *later* task is implemented (the feature it exercises doesn't exist yet), do not mark it Done and do not skip it silently — leave it `🔄 In Progress · <today's date> (depends on T0XX)`, implement T0XX, then return and finish it. Record the pair in `docs/handoff.md`'s "Next" section so it survives a session boundary. See `docs/tasks.md`'s legend for the exact convention.
- If a task can't be completed, mark it `⛔ Blocked · <reason>` in `docs/tasks.md` instead of guessing or skipping silently. An unanswered question that blocks only this task is that task's blocker. A question that blocks ALL further work (no task can safely proceed until it's answered) is a project-wide blocker: mark the next task to be worked `⛔ Blocked · <reason>` too — blocker detection only scans task rows in `docs/tasks.md`, so leaving it solely in `docs/handoff.md`'s "Blockers" section will not trigger notification. If the question doesn't block any task, leave it under "Open questions" in `docs/handoff.md` instead and carry it forward unchanged until it's answered.

## Ending a Session
- Update `docs/tasks.md` (status of completed items, in-progress notes, blockers).
- Update `docs/handoff.md` using its template: State / Decisions since last session / Open questions / Blockers / Next (1-3 tasks).
- In VS Code Copilot Chat, a `Stop` hook (`.github/hooks/handoff-check.json`) checks `docs/tasks.md` for `⛔ Blocked` items and notifies via `notify.sh` — see `external/ai-session-kit/scripts/check-handoff.sh`. In Cline (CLI and VS Code extension), the equivalent lifecycle hooks are `.cline/hooks/{TaskComplete,TaskCancel,SessionShutdown}.sh` and `.clinerules/hooks/{TaskComplete,TaskCancel,SessionShutdown}` (no file extension — both locations are required; each Cline surface only reads hooks from its own directory), which call the same check via `external/ai-session-kit/scripts/check-handoff-cline.sh`. Implement `notify.sh` with a real notification (email/Slack/etc); it's a stub until you do.

## Token Efficiency
- Keep sessions short: treat one task as the normal unit of work and stop — update `docs/handoff.md` and end the session — rather than continuing into a second or third task just because more are ready, even in auto-continue mode where each iteration is already scoped to one task.
- Keep each session scoped to 1-3 tasks.
- Don't re-read files already read earlier in the same session; prefer targeted edits over full-file rewrites.

## Frontend
If this project has a UI, `.github/instructions/frontend.instructions.md` holds Copilot's conventions (`applyTo` glob), and `.clinerules/frontend.md` holds Cline's equivalent (`paths` glob in YAML frontmatter). Both are created by the `/technical-spec` prompt or skill once the stack is chosen — don't hand-write them before that decision exists.

## Build and Test
{Fill in once the project is scaffolded: install/build/test commands.}
