#!/usr/bin/env bash
# Thin wrapper — Cline requires hooks to be actual executable files at this
# exact name/location (unlike Copilot's hook config, which is a JSON manifest
# that can point anywhere). Real logic is vendored and read-only; see
# external/ai-session-kit/scripts/cline-tool-guard.sh.
#
# A near-identical copy also lives at .clinerules/hooks/PreToolUse (no file
# extension) — the Cline VS Code extension and the Cline CLI each only
# discover hooks from their own directory convention, confirmed empirically.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/external/ai-session-kit/scripts/cline-tool-guard.sh"
