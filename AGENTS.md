# Project Guidelines

## Session Start
- Read `docs/functional-spec.md`, `docs/technical-spec.md`, `docs/tasks.md`, and `docs/handoff.md` before doing anything else (a `SessionStart`-equivalent check also happens via the Stop hook from the previous session).
- Work only the task(s) listed under "Next" in `docs/handoff.md` — don't scope-creep into later sprints.

## Methodology
- Test-driven: write a failing test before implementation code, for every task.
- Sprint-based: work exactly one task from `docs/tasks.md` at a time. Check it off only when its tests pass.
- If a task can't be completed, mark it `BLOCKED: <reason>` in `docs/tasks.md` instead of guessing or skipping silently.

## Ending a Session
- Update `docs/tasks.md` (check off completed items, mark blockers).
- Update `docs/handoff.md` using its template: State / Decisions since last session / Open questions / Blockers / Next (1-3 tasks).
- A `Stop` hook (`.github/hooks/handoff-check.json`) checks `docs/tasks.md` for `BLOCKED` items and notifies via `notify.sh` — see `external/ai-session-kit/scripts/check-handoff.sh`. Implement `notify.sh` with a real notification (email/Slack/etc); it's a stub until you do.

## Token Efficiency
- Keep each session scoped to 1-3 tasks.
- Don't re-read files already read earlier in the same session; prefer targeted edits over full-file rewrites.

## Frontend
If this project has a UI, `.github/instructions/frontend.instructions.md` holds its conventions and auto-attaches when frontend files are touched. It's created by the `/technical-spec` prompt once the stack is chosen — don't hand-write it before that decision exists.

## Build and Test

Prerequisites: `brew install bash bats-core jq` (macOS), or equivalent on Linux/Git Bash.

Run the full test suite:
```
./tests/run_tests.sh
```

Run a single suite:
```
bats tests/unit/sha256.bats
bats tests/integration/minimal.bats
```

Note: test files do not exist until T32 is implemented. The commands above are the
intended interface — implementing agents should run them to verify work as they go.
