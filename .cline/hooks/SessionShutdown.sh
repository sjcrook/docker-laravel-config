#!/usr/bin/env bash
# Thin wrapper — Cline requires hooks to be actual executable files at this
# exact name/location. Real logic is vendored and read-only; see
# external/ai-session-kit/scripts/check-handoff-cline.sh.
#
# Registered alongside TaskComplete.sh and TaskCancel.sh: which one fires
# depends on the surface and how the session ended (confirmed empirically) —
# this one reliably fired when a headless CLI run was killed with SIGINT
# (TaskCancel.sh did not), but did NOT fire when the user clicked Cancel in
# the VS Code extension's panel (TaskCancel.sh covers that case instead). A
# near-identical copy also lives at .clinerules/hooks/SessionShutdown (no file
# extension) for the VS Code extension, which doesn't discover hooks from
# this directory.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/external/ai-session-kit/scripts/check-handoff-cline.sh"
