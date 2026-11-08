#!/usr/bin/env bats
# T20 — load_answers() and validate_answers() (tech §8, §9)

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

# Load an answers file and validate it in the current shell.
@test "load_answers: reads all 14 value fields from full example" {
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    [ "${ANSWERS[phpVersion]}" = "8.5" ]
    [ "${ANSWERS[pgClientVersion]}" = "18" ]
    [ "${ANSWERS[domain]}" = "myapp.com" ]
    [ "${ANSWERS[domainAliases]}" = "www.myapp.com test.myapp.com" ]
    [ "${ANSWERS[memoryLimit]}" = "256M" ]
    [ "${ANSWERS[uploadMaxFilesize]}" = "64M" ]
    [ "${ANSWERS[postMaxSize]}" = "64M" ]
    [ "${ANSWERS[timezone]}" = "America/New_York" ]
    [ "${ANSWERS[phpFpmIncludeNode]}" = "false" ]
    [ "${ANSWERS[nodeServiceBlock]}" = "builtin" ]
    [ "${ANSWERS[hostHttpPort]}" = "80" ]
    [ "${ANSWERS[hostHttpsPort]}" = "443" ]
    [ "${ANSWERS[hostSshPort]}" = "2222" ]
    [ "${ANSWERS[hostPgAdminPort]}" = "8081" ]
}

@test "load_answers: optional field defaults applied for minimal example" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
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

@test "load_answers: phpFpmIncludeNode true is loaded as true" {
    echo '{"phpVersion":"8.5","pgClientVersion":18,"domain":"a.b","phpFpmIncludeNode":true}' > "$TMP/a.json"
    load_answers "$TMP/a.json"
    [ "${ANSWERS[phpFpmIncludeNode]}" = "true" ]
}

@test "load_answers: missing file exits 1 with path in message" {
    run load_answers "$TMP/nope.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$TMP/nope.json"* ]]
}

@test "validate_answers: passes minimal example" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    run validate_answers
    [ "$status" -eq 0 ]
}

@test "validate_answers: passes full example" {
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    run validate_answers
    [ "$status" -eq 0 ]
}

@test "validate_answers: fails empty domain" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[domain]=""
    run validate_answers
    [ "$status" -eq 1 ]
    [[ "$output" == *"domain"* ]]
}

@test "validate_answers: fails empty phpVersion" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[phpVersion]=""
    run validate_answers
    [ "$status" -eq 1 ]
    [[ "$output" == *"phpVersion"* ]]
}

@test "validate_answers: fails port 0" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[hostHttpPort]=0
    run validate_answers
    [ "$status" -eq 1 ]
    [[ "$output" == *"hostHttpPort"* ]]
}

@test "validate_answers: fails port 65536" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[hostPgAdminPort]=65536
    run validate_answers
    [ "$status" -eq 1 ]
    [[ "$output" == *"hostPgAdminPort"* ]]
}

@test "validate_answers: fails non-numeric port" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[hostSshPort]="abc"
    run validate_answers
    [ "$status" -eq 1 ]
}

@test "validate_answers: accepts port 1 and 65535" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[hostHttpPort]=1
    ANSWERS[hostHttpsPort]=65535
    run validate_answers
    [ "$status" -eq 0 ]
}

@test "validate_answers: fails phpFpmIncludeNode=\"yes\"" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[phpFpmIncludeNode]="yes"
    run validate_answers
    [ "$status" -eq 1 ]
    [[ "$output" == *"phpFpmIncludeNode"* ]]
}

@test "validate_answers: fails non-existent nodeServiceBlock path" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    ANSWERS[nodeServiceBlock]="no/such/file.yml"
    run validate_answers
    [ "$status" -eq 1 ]
    [[ "$output" == *"no/such/file.yml"* ]]
}

@test "validate_answers: accepts nodeServiceBlock path existing relative to OUT_DIR" {
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    echo "  node: {}" > "$TMP/custom.yml"
    ANSWERS[nodeServiceBlock]="custom.yml"
    run validate_answers
    [ "$status" -eq 0 ]
}

# T21 — save_answers() (tech §14)

@test "save_answers: writes valid JSON to OUT_DIR/docker.answers.json" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    save_answers "$TMP"
    [ -f "$TMP/docker.answers.json" ]
    jq -e . "$TMP/docker.answers.json" >/dev/null
}

@test "save_answers: integer fields are JSON numbers" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    save_answers "$TMP"
    run jq -r '[.schemaVersion,.pgClientVersion,.hostHttpPort,.hostHttpsPort,.hostSshPort,.hostPgAdminPort] | map(type) | unique | join(",")' "$TMP/docker.answers.json"
    [ "$output" = "number" ]
}

@test "save_answers: phpFpmIncludeNode is a JSON boolean" {
    set -e
    echo '{"phpVersion":"8.5","pgClientVersion":18,"domain":"a.b","phpFpmIncludeNode":true}' > "$TMP/a.json"
    load_answers "$TMP/a.json"
    save_answers "$TMP"
    run jq -c '.phpFpmIncludeNode' "$TMP/docker.answers.json"
    [ "$output" = "true" ]
}

@test "save_answers: string fields are JSON strings and schemaVersion is 1" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    save_answers "$TMP"
    [ "$(jq -r '.phpVersion|type' "$TMP/docker.answers.json")" = "string" ]
    [ "$(jq -r '.schemaVersion' "$TMP/docker.answers.json")" = "1" ]
}

@test "save_answers: round-trips via load_answers with identical values" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    declare -A before=()
    local k
    for k in "${!ANSWERS[@]}"; do before[$k]="${ANSWERS[$k]}"; done
    save_answers "$TMP"
    ANSWERS=()
    load_answers "$TMP/docker.answers.json"
    [ "${#ANSWERS[@]}" -eq "${#before[@]}" ]
    for k in "${!before[@]}"; do [ "${ANSWERS[$k]}" = "${before[$k]}" ]; done
}

@test "save_answers: minimal example round-trips with defaults filled in" {
    set -e
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
    save_answers "$TMP"
    [ "$(jq -r '.memoryLimit' "$TMP/docker.answers.json")" = "256M" ]
    [ "$(jq -r '.hostHttpPort' "$TMP/docker.answers.json")" = "80" ]
}
