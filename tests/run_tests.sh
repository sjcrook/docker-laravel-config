#!/usr/bin/env bash
set -euo pipefail
command -v bats >/dev/null 2>&1 || {
    echo "ERROR: bats not found. Install: brew install bats-core"; exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bats --tap "${SCRIPT_DIR}/unit" "${SCRIPT_DIR}/integration"
