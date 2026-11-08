#!/usr/bin/env bats
# T19 — interactive_prompts() (tech §7)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
    TMP="$(mktemp -d)"
    OUT_DIR="$TMP"
}

teardown() {
    rm -rf "$TMP"
}

# Feed lines to interactive_prompts via stdin.
run_prompts() {
    printf '%b' "$1" > "$TMP/input"
    interactive_prompts < "$TMP/input" > "$TMP/stdout"
}

# Build n blank lines (accept defaults).
blanks() { local i; for ((i=0;i<$1;i++)); do printf '%s' '\n'; done; }

@test "interactive_prompts: Enter accepts all defaults (domain supplied)" {
    set -e
    run_prompts "\n\nmyapp.test\n$(blanks 10)"
    [ "${ANSWERS[phpVersion]}" = "8.5" ]
    [ "${ANSWERS[pgClientVersion]}" = "18" ]
    [ "${ANSWERS[domain]}" = "myapp.test" ]
    [ "${ANSWERS[domainAliases]}" = "" ]
    [ "${ANSWERS[memoryLimit]}" = "256M" ]
    [ "${ANSWERS[uploadMaxFilesize]}" = "64M" ]
    [ "${ANSWERS[postMaxSize]}" = "64M" ]
    [ "${ANSWERS[timezone]}" = "America/New_York" ]
    [ "${ANSWERS[phpFpmIncludeNode]}" = "false" ]
    [ "${ANSWERS[nodeServiceBlock]}" = "none" ]
    [ "${ANSWERS[hostHttpPort]}" = "80" ]
    [ "${ANSWERS[hostHttpsPort]}" = "443" ]
    [ "${ANSWERS[hostSshPort]}" = "2222" ]
    [ "${ANSWERS[hostPgAdminPort]}" = "8081" ]
}

@test "interactive_prompts: prompts are asked in the documented order" {
    set -e
    run_prompts '8.4\n17\nmyapp.test\nwww.myapp.test\n512M\n32M\nUTC\ny\nbuiltin\n8080\n8443\n2200\n8082\n'
    [ "${ANSWERS[phpVersion]}" = "8.4" ]
    [ "${ANSWERS[pgClientVersion]}" = "17" ]
    [ "${ANSWERS[domain]}" = "myapp.test" ]
    [ "${ANSWERS[domainAliases]}" = "www.myapp.test" ]
    [ "${ANSWERS[memoryLimit]}" = "512M" ]
    [ "${ANSWERS[uploadMaxFilesize]}" = "32M" ]
    [ "${ANSWERS[postMaxSize]}" = "32M" ]
    [ "${ANSWERS[timezone]}" = "UTC" ]
    [ "${ANSWERS[phpFpmIncludeNode]}" = "true" ]
    [ "${ANSWERS[nodeServiceBlock]}" = "builtin" ]
    [ "${ANSWERS[hostHttpPort]}" = "8080" ]
    [ "${ANSWERS[hostHttpsPort]}" = "8443" ]
    [ "${ANSWERS[hostSshPort]}" = "2200" ]
    [ "${ANSWERS[hostPgAdminPort]}" = "8082" ]
}

@test "interactive_prompts: domain loops until non-empty" {
    set -e
    run_prompts "\n\n\n\nmyapp.test\n$(blanks 10)"
    [ "${ANSWERS[domain]}" = "myapp.test" ]
}

@test "interactive_prompts: phpFpmIncludeNode y/Y -> true, n/N/empty -> false" {
    set -e
    run_prompts "\n\na.test\n$(blanks 4)Y\n$(blanks 5)"
    [ "${ANSWERS[phpFpmIncludeNode]}" = "true" ]
    run_prompts "\n\na.test\n$(blanks 4)n\n$(blanks 5)"
    [ "${ANSWERS[phpFpmIncludeNode]}" = "false" ]
    run_prompts "\n\na.test\n$(blanks 4)N\n$(blanks 5)"
    [ "${ANSWERS[phpFpmIncludeNode]}" = "false" ]
}

@test "interactive_prompts: nodeServiceBlock=path asks for a path and validates it exists" {
    set -e
    echo "  node:" > "$TMP/node.yml"
    run_prompts "\n\na.test\n$(blanks 5)path\nmissing.yml\nnode.yml\n$(blanks 4)"
    [ "${ANSWERS[nodeServiceBlock]}" = "node.yml" ]
    [ "${ANSWERS[hostHttpPort]}" = "80" ]
}

@test "interactive_prompts: ports and node flag are bare JSON values in saved file" {
    set -e
    run_prompts "\n\na.test\n$(blanks 6)9000\n$(blanks 3)"
    [ "$(jq -r '.hostHttpPort | type' "$TMP/docker.answers.json")" = "number" ]
    [ "$(jq -r '.hostHttpPort' "$TMP/docker.answers.json")" = "9000" ]
    [ "$(jq -r '.phpFpmIncludeNode | type' "$TMP/docker.answers.json")" = "boolean" ]
}

@test "interactive_prompts: calls save_answers and round-trips via load_answers" {
    set -e
    run_prompts "\n\na.test\nwww.a.test\n$(blanks 9)"
    [ -f "$TMP/docker.answers.json" ]
    declare -A saved
    local k
    for k in "${!ANSWERS[@]}"; do saved[$k]="${ANSWERS[$k]}"; done
    ANSWERS=()
    load_answers "$TMP/docker.answers.json"
    for k in "${!saved[@]}"; do [ "${ANSWERS[$k]}" = "${saved[$k]}" ]; done
}

@test "interactive_prompts: EOF on stdin exits 1 instead of looping forever" {
    run bash -c "source '${REPO_ROOT}/generate.sh'; OUT_DIR='$TMP'; interactive_prompts < /dev/null"
    [ "$status" -eq 1 ]
}
