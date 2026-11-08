#!/usr/bin/env bats
# Integration — hand-edit detection (tech §20: hand_edit.bats)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TEST_OUT="$(mktemp -d)"
    # First run to set up baseline
    "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}" >/dev/null
}

teardown() {
    rm -rf "${TEST_OUT}"
}

@test "hand_edit: second run with no edits exits 0 and writes no .new files" {
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}"
    [ "$status" -eq 0 ]
    local count
    count="$(find "${TEST_OUT}" -name '*.new' | wc -l)"
    [ "$count" -eq 0 ]
}

@test "hand_edit: second run after editing generated file writes .new and leaves original unchanged" {
    # Edit the generated docker-compose.yml
    echo "# hand edit" >> "${TEST_OUT}/docker-compose.yml"
    cp "${TEST_OUT}/docker-compose.yml" "${TEST_OUT}/docker-compose.yml.orig"
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}"
    [ "$status" -eq 0 ]
    [ -f "${TEST_OUT}/docker-compose.yml.new" ]
    # Original unchanged
    cmp "${TEST_OUT}/docker-compose.yml" "${TEST_OUT}/docker-compose.yml.orig"
}

@test "hand_edit: second run with --force after edit overwrites original, no .new file" {
    echo "# hand edit" >> "${TEST_OUT}/docker-compose.yml"
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}" --force
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_OUT}/docker-compose.yml.new" ]
    # Original must no longer contain the hand-edit line
    ! grep -q '# hand edit' "${TEST_OUT}/docker-compose.yml"
}

@test "hand_edit: second run on invariant file always overwrites, no .new written" {
    # Invariant files have no header, so editing them doesn't trigger .new logic
    echo "# hand edit" >> "${TEST_OUT}/sail"
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}"
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_OUT}/sail.new" ]
    # The sail file should be overwritten back to the original
    ! grep -q '# hand edit' "${TEST_OUT}/sail"
}
