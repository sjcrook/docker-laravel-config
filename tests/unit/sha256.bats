#!/usr/bin/env bats
# T18 — sha256_file() / sha256_string() (tech §6)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
    ORIG_PATH="$PATH"
    TMP="$(mktemp -d)"
    printf 'hello world' > "${TMP}/f.txt"
    # SHA-256 of "hello world"
    EXPECTED="b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
}

teardown() {
    PATH="$ORIG_PATH"
    rm -rf "$TMP"
}

# Build a PATH containing only the named tools (plus awk/printf deps) so that
# the others appear absent.
limited_path() {
    local bin="${TMP}/bin" t
    mkdir -p "$bin"
    for t in awk "$@"; do
        ln -sf "$(command -v "$t")" "${bin}/${t}"
    done
    echo "$bin"
}

@test "sha256_file: returns 64-char lowercase hex" {
    run sha256_file "${TMP}/f.txt"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "sha256_string: returns 64-char lowercase hex" {
    run sha256_string "hello world"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "sha256_file: is deterministic and correct" {
    run sha256_file "${TMP}/f.txt"
    [ "$output" = "$EXPECTED" ]
    run sha256_file "${TMP}/f.txt"
    [ "$output" = "$EXPECTED" ]
}

@test "sha256_string: is deterministic and correct" {
    run sha256_string "hello world"
    [ "$output" = "$EXPECTED" ]
    run sha256_string "hello world"
    [ "$output" = "$EXPECTED" ]
}

@test "sha256_file and sha256_string agree on the same content" {
    a="$(sha256_file "${TMP}/f.txt")"
    b="$(sha256_string "hello world")"
    [ "$a" = "$b" ]
}

@test "sha256: sha256sum absent -> shasum is used" {
    command -v shasum >/dev/null 2>&1 || skip "shasum not installed"
    PATH="$(limited_path shasum perl)"
    run sha256_string "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "$EXPECTED" ]
    run sha256_file "${TMP}/f.txt"
    [ "$output" = "$EXPECTED" ]
}

@test "sha256: sha256sum and shasum absent -> openssl is used" {
    command -v openssl >/dev/null 2>&1 || skip "openssl not installed"
    PATH="$(limited_path openssl)"
    run sha256_string "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "$EXPECTED" ]
    run sha256_file "${TMP}/f.txt"
    [ "$output" = "$EXPECTED" ]
}

@test "sha256: all three tools absent -> exits 1 with error message" {
    PATH="$(limited_path)"
    run sha256_string "x"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No SHA-256 tool found"* ]]
    run sha256_file "${TMP}/f.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No SHA-256 tool found"* ]]
}
