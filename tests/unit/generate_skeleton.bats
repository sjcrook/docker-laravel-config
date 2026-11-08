#!/usr/bin/env bats
# T17 — generate.sh skeleton, print_usage(), check_deps() (tech §2, §5)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    GEN="${REPO_ROOT}/generate.sh"
    EMPTY_BIN="$(mktemp -d)"
}

teardown() {
    rm -rf "$EMPTY_BIN"
}

@test "generate.sh: exists and is executable" {
    [ -x "$GEN" ]
}

@test "generate.sh: first line is #!/usr/bin/env bash" {
    [ "$(head -n1 "$GEN")" = '#!/usr/bin/env bash' ]
}

@test "generate.sh: --help exits 0 and prints usage" {
    run "$GEN" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--answers"* ]]
    [[ "$output" == *"--out-dir"* ]]
    [[ "$output" == *"--force"* ]]
}

@test "generate.sh: -h also exits 0 with usage" {
    run "$GEN" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "generate.sh: sourcing does not run main" {
    run bash -c "source '$GEN'; echo sourced-ok"
    [ "$status" -eq 0 ]
    [ "$output" = "sourced-ok" ]
}

@test "generate.sh: SCRIPT_DIR and TEMPLATES_DIR resolve when run from another cwd" {
    run bash -c "cd /tmp && source '$GEN' && echo \"\$SCRIPT_DIR\" && echo \"\$TEMPLATES_DIR\""
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$REPO_ROOT" ]
    [ "${lines[1]}" = "${REPO_ROOT}/templates" ]
}

@test "generate.sh: --help works from a different working directory" {
    run bash -c "cd /tmp && '$GEN' --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "check_deps: passes when bash >= 4 and jq present" {
    command -v jq >/dev/null
    run bash -c "source '$GEN'; check_deps"
    [ "$status" -eq 0 ]
}

@test "check_deps: exits 1 with bash version message and brew hint when bash < 4" {
    run bash -c "source '$GEN'; GENERATE_BASH_MAJOR=3 check_deps"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bash 4.0+ required"* ]]
    [[ "$output" == *"brew install bash"* ]]
}

@test "check_deps: exits 1 with jq install hints when jq is absent" {
    run bash -c "source '$GEN'; PATH='$EMPTY_BIN' check_deps"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing required tool: jq"* ]]
    [[ "$output" == *"brew install jq"* ]]
    [[ "$output" == *"apt install jq"* ]]
    [[ "$output" == *"https://stedolan.github.io/jq/"* ]]
}
