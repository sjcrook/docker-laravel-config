#!/usr/bin/env bash
# Shared setup/teardown helpers for bats integration tests.

setup() {
    TEST_OUT="$(mktemp -d)"
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
}

teardown() {
    rm -rf "${TEST_OUT}"
}
