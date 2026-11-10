# Project workflow entry point

Follow the repository-root [AGENTS.md](../AGENTS.md). Read it from disk before
executing any kit slash command. Resolve this link relative to this instruction
file in `.github/`, not relative to the working directory. For file tools, use
`<repository-root>/AGENTS.md`; do not use `<repository-root>/../AGENTS.md`.
The repository root is the current project's Git root, not its parent directory.
If the root is uncertain, ask the developer rather than probing parent folders.

Apply its Readiness and Steering contract to equivalent plain-language workflow
requests too. Explain missing prerequisites and ask before starting another
workflow; do not treat an out-of-order request as a reason to run prohibited tools.

This includes a literal `/tasks` message that the
chat interface has not expanded. Use its Literal Slash Commands mapping to load
the current workspace prompt, role, and referenced workflow instructions.
`/tasks` requests requirement reconciliation and backlog planning, not a task
status summary, even when every existing task is Done.

This is best-effort loading guidance, not an enforced router. For role-restricted
work, the developer should explicitly select the mapped custom agent in the
picker. Do not claim that reading a role file activates its tool permissions.

General questions do not activate the structured workflow or require project
document reads. Do not execute commands merely mentioned in a question.
