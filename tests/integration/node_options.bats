#!/usr/bin/env bats
# Integration — node service and php-fpm node inclusion options (tech §20: node_options.bats)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TEST_OUT="$(mktemp -d)"
}

teardown() {
    rm -rf "${TEST_OUT}"
}

# Helper: write a minimal answers JSON with overrides.
write_answers() {
    local file="$1"; shift
    local base; base="$(cat "${REPO_ROOT}/examples/minimal.answers.json")"
    local out="$base"
    while [ $# -ge 2 ]; do
        local key="$1" val="$2"; shift 2
        out="$(echo "$out" | jq --arg k "$key" --argjson v "$val" '. + {($k): $v}')"
    done
    echo "$out" > "$file"
}

@test "node_options: nodeServiceBlock=none -> no node:20-alpine in compose" {
    write_answers "${TEST_OUT}/a.json" nodeServiceBlock '"none"'
    mkdir -p "${TEST_OUT}/out"
    "${REPO_ROOT}/generate.sh" --answers "${TEST_OUT}/a.json" --out-dir "${TEST_OUT}/out" >/dev/null
    ! grep -q 'node:20-alpine' "${TEST_OUT}/out/docker-compose.yml"
}

@test "node_options: nodeServiceBlock=builtin -> node:20-alpine and empty entrypoint present" {
    write_answers "${TEST_OUT}/a.json" nodeServiceBlock '"builtin"'
    mkdir -p "${TEST_OUT}/out"
    "${REPO_ROOT}/generate.sh" --answers "${TEST_OUT}/a.json" --out-dir "${TEST_OUT}/out" >/dev/null
    grep -qF 'node:20-alpine' "${TEST_OUT}/out/docker-compose.yml"
    grep -qF 'entrypoint: [""]' "${TEST_OUT}/out/docker-compose.yml"
}

@test "node_options: nodeServiceBlock=custom path -> custom file content in compose" {
    echo "    custom_node:" > "${TEST_OUT}/custom.yml"
    echo "        image: node:lts" >> "${TEST_OUT}/custom.yml"
    write_answers "${TEST_OUT}/a.json" nodeServiceBlock '"custom.yml"'
    "${REPO_ROOT}/generate.sh" --answers "${TEST_OUT}/a.json" --out-dir "${TEST_OUT}" >/dev/null
    grep -qF 'custom_node:' "${TEST_OUT}/docker-compose.yml"
    grep -qF 'node:lts' "${TEST_OUT}/docker-compose.yml"
}

@test "node_options: nodeServiceBlock=bad path -> exits 1 with path in stderr" {
    write_answers "${TEST_OUT}/a.json" nodeServiceBlock '"no/such/file.yml"'
    mkdir -p "${TEST_OUT}/out"
    run "${REPO_ROOT}/generate.sh" --answers "${TEST_OUT}/a.json" --out-dir "${TEST_OUT}/out"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no/such/file.yml"* ]]
}

@test "node_options: phpFpmIncludeNode=true -> nodejs npm in Dockerfile" {
    write_answers "${TEST_OUT}/a.json" phpFpmIncludeNode 'true'
    mkdir -p "${TEST_OUT}/out"
    "${REPO_ROOT}/generate.sh" --answers "${TEST_OUT}/a.json" --out-dir "${TEST_OUT}/out" >/dev/null
    grep -q 'nodejs npm' "${TEST_OUT}/out/docker/php-fpm/Dockerfile"
}

@test "node_options: phpFpmIncludeNode=false -> nodejs absent from Dockerfile" {
    write_answers "${TEST_OUT}/a.json" phpFpmIncludeNode 'false'
    mkdir -p "${TEST_OUT}/out"
    "${REPO_ROOT}/generate.sh" --answers "${TEST_OUT}/a.json" --out-dir "${TEST_OUT}/out" >/dev/null
    ! grep -q 'nodejs' "${TEST_OUT}/out/docker/php-fpm/Dockerfile"
}
