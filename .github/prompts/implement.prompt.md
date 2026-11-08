---
description: "Implement the next task from docs/tasks.md using test-driven development"
agent: implementer
---
Before selecting or changing any task, run `bash external/ai-session-kit/scripts/check-planning.sh`. Stop on failure and request `/tasks` and explicit approval; never edit `docs/planning/` or select Superseded work. Implement the next eligible task from [docs/tasks.md](../../docs/tasks.md), following the project workflow in [AGENTS.md](../../AGENTS.md). Work on exactly one task: mark it In Progress before starting, write an acceptance test, implement any needed change, run the tests, and update its task status when complete.

For new or changed behavior, confirm the test fails because the required behavior is missing before implementing it. For regression-only tasks covering existing behavior, a correct test may pass immediately; record that no implementation change or red phase was needed. Never manufacture a failure by using incorrect expectations or temporarily breaking working code.

Use file-editing tools to create or edit source and tests, never shell writes (including printf/echo redirection, heredocs, or interpreter-based writes). If these tools are unavailable, report the limitation and mark the task Blocked.

If the task is genuinely blocked, immediately mark its row `⛔ Blocked · <reason>` in `docs/tasks.md` and explain the blocker. Do not write a session handoff; run `/handoff` separately when ending the session.
