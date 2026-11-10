#!/usr/bin/env bash
# Thin wrapper — Cline requires hooks to be actual executable files at this
# exact name/location. Real logic is vendored and read-only; see
# external/ai-session-kit/scripts/check-handoff-cline.sh.
#
# Registered alongside TaskCancel.sh and SessionShutdown.sh: which one fires
# depends on the surface and how the session ended (confirmed empirically) —
# this one fires on normal completion, on both the CLI and the VS Code
# extension. A near-identical copy also lives at .clinerules/hooks/TaskComplete
# (no file extension) for the VS Code extension, which doesn't discover hooks
# from this directory.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/external/ai-session-kit/scripts/check-handoff-cline.sh" TaskComplete
