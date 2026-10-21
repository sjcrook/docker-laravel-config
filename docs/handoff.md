# Handoff

_Overwritten each session — a snapshot, not a log. Permanent decisions belong in commit messages / PR descriptions, not here._

## State
All planning is complete. Functional spec, technical spec (including final portability
decisions), and task list T01–T32 are finalised and committed. Both submodules are in place
(`external/ai-session-kit`, `external/dev-container-config`). No implementation has started.

## Decisions since last session
- Python 3 replaced with Perl for token substitution (`render_template()`) — pre-installed on macOS, Linux, and Git Bash; no install required
- `sail` changed from `#!/bin/zsh` + `${PWD:t}` to `#!/usr/bin/env bash` + `$(basename "$PWD")` — POSIX-portable, works on Linux and Git Bash
- SHA-256 helpers use a three-way fallback chain: `sha256sum` → `shasum -a 256` → `openssl dgst -sha256`
- `check_deps()` now checks bash 4+ as its first guard (macOS ships bash 3.2; fix is `brew install bash`)
- `openssl dgst` added as tertiary SHA-256 fallback only — `sha256sum` and `shasum` remain preferred

## Open questions
- None

## Blockers
- None

## Next (1-3 tasks)
- [ ] T01 · Initialise directory structure and `.gitignore`
- [ ] T02 · `templates/docker/nginx/Dockerfile`
- [ ] T03 · `templates/docker/nginx/nginx.conf`
