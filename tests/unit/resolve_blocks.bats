#!/usr/bin/env bats
# T23 — resolve_blocks() (tech §10)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
    TMP="$(mktemp -d)"
    OUT_DIR="$TMP"
    unset TOKEN_NODE_SERVICE_BLOCK TOKEN_NODE_APT_BLOCK
    load_answers "${REPO_ROOT}/examples/minimal.answers.json"
}

teardown() {
    rm -rf "$TMP"
}

@test "resolve_blocks: nodeServiceBlock=none gives empty token" {
    set -e
    ANSWERS[nodeServiceBlock]="none"
    resolve_blocks
    [ -z "$TOKEN_NODE_SERVICE_BLOCK" ]
}

@test "resolve_blocks: nodeServiceBlock=builtin gives snippet content" {
    set -e
    ANSWERS[nodeServiceBlock]="builtin"
    resolve_blocks
    [ "$TOKEN_NODE_SERVICE_BLOCK" = "$(cat "${REPO_ROOT}/templates/snippets/node-service.yml")" ]
    [[ "$TOKEN_NODE_SERVICE_BLOCK" == *"node:20-alpine"* ]]
}

@test "resolve_blocks: custom path gives that file's content" {
    set -e
    printf '    custom:\n        image: foo\n' > "${OUT_DIR}/custom.yml"
    ANSWERS[nodeServiceBlock]="custom.yml"
    resolve_blocks
    [ "$TOKEN_NODE_SERVICE_BLOCK" = "$(cat "${OUT_DIR}/custom.yml")" ]
}

@test "resolve_blocks: tokens are exported to child processes" {
    set -e
    ANSWERS[nodeServiceBlock]="builtin"
    resolve_blocks
    run bash -c 'echo "$TOKEN_NODE_SERVICE_BLOCK"'
    [[ "$output" == *"node:20-alpine"* ]]
}

@test "resolve_blocks: phpFpmIncludeNode=false gives empty NODE_APT_BLOCK" {
    set -e
    ANSWERS[phpFpmIncludeNode]="false"
    resolve_blocks
    [ -z "$TOKEN_NODE_APT_BLOCK" ]
}

@test "resolve_blocks: phpFpmIncludeNode=true gives apt-get update then install nodejs npm" {
    set -e
    ANSWERS[phpFpmIncludeNode]="true"
    resolve_blocks
    [[ "$TOKEN_NODE_APT_BLOCK" == *"apt-get update"* ]]
    [[ "$TOKEN_NODE_APT_BLOCK" == *"apt-get install"* ]]
    [[ "$TOKEN_NODE_APT_BLOCK" == *"nodejs"* ]]
    [[ "$TOKEN_NODE_APT_BLOCK" == *"npm"* ]]
    [[ "$TOKEN_NODE_APT_BLOCK" == *"rm -rf /var/lib/apt/lists/*"* ]]
}
