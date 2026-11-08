#!/usr/bin/env bats
# T18 — parse_args() (tech §4)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
}

@test "parse_args: defaults before parsing" {
    [ -z "$ANSWERS_FILE" ]
    [ "$FORCE" = "false" ]
    [ "$OUT_DIR" = "$(pwd)" ]
}

@test "parse_args: --answers sets ANSWERS_FILE" {
    parse_args --answers /tmp/a.json
    [ "$ANSWERS_FILE" = "/tmp/a.json" ]
}

@test "parse_args: --out-dir sets OUT_DIR" {
    parse_args --out-dir /tmp/out
    [ "$OUT_DIR" = "/tmp/out" ]
}

@test "parse_args: --force sets FORCE=true" {
    parse_args --force
    [ "$FORCE" = "true" ]
}

@test "parse_args: all flags together" {
    parse_args --force --answers a.json --out-dir o
    [ "$FORCE" = "true" ]
    [ "$ANSWERS_FILE" = "a.json" ]
    [ "$OUT_DIR" = "o" ]
}

@test "parse_args: unknown flag exits 1 and prints usage" {
    run parse_args --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "parse_args: --answers without a value exits 1" {
    run parse_args --answers
    [ "$status" -eq 1 ]
}

@test "parse_args: --out-dir without a value exits 1" {
    run parse_args --out-dir
    [ "$status" -eq 1 ]
}

@test "main: unknown flag exits 1 via subprocess" {
    run "${REPO_ROOT}/generate.sh" --bogus
    [ "$status" -eq 1 ]
}
