#!/usr/bin/env bats
# T016 — examples/*.answers.json (technical-spec §18)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    MINIMAL="${REPO_ROOT}/examples/minimal.answers.json"
    FULL="${REPO_ROOT}/examples/full.answers.json"
    SCHEMA="${REPO_ROOT}/schema/answers.schema.json"
}

@test "minimal.answers.json exists and is valid JSON" {
    [ -f "$MINIMAL" ]
    jq -e . "$MINIMAL" >/dev/null
}

@test "full.answers.json exists and is valid JSON" {
    [ -f "$FULL" ]
    jq -e . "$FULL" >/dev/null
}

@test "minimal has only the four required fields" {
    run jq -r 'keys | join(" ")' "$MINIMAL"
    [ "$output" = "domain pgClientVersion phpVersion schemaVersion" ]
}

@test "minimal has the spec values" {
    [ "$(jq -c . "$MINIMAL")" = '{"schemaVersion":1,"phpVersion":"8.5","pgClientVersion":18,"domain":"myapp.local"}' ]
}

@test "full has exactly the 16 schema fields" {
    run jq -r 'keys | join(" ")' "$FULL"
    expected="$(jq -r '.properties | keys | join(" ")' "$SCHEMA")"
    [ "$output" = "$expected" ]
}

@test "full uses canonical defaults for optional fields" {
    run jq -c '{memoryLimit,uploadMaxFilesize,postMaxSize,timezone,phpFpmIncludeNode,hostHttpPort,hostHttpsPort,hostSshPort,hostPgAdminPort,hostVitePort}' "$FULL"
    [ "$output" = '{"memoryLimit":"256M","uploadMaxFilesize":"64M","postMaxSize":"64M","timezone":"America/New_York","phpFpmIncludeNode":false,"hostHttpPort":80,"hostHttpsPort":443,"hostSshPort":2222,"hostPgAdminPort":8081,"hostVitePort":5173}' ]
}

@test "full uses the builtin node service and example domain/aliases" {
    [ "$(jq -r .nodeServiceBlock "$FULL")" = "builtin" ]
    [ "$(jq -r .domain "$FULL")" = "myapp.com" ]
    [ "$(jq -r .domainAliases "$FULL")" = "www.myapp.com test.myapp.com" ]
}
