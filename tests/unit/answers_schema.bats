#!/usr/bin/env bats
# T015 — schema/answers.schema.json (technical-spec §17)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCHEMA="${REPO_ROOT}/schema/answers.schema.json"
}

@test "schema file exists and is valid JSON" {
    [ -f "$SCHEMA" ]
    jq -e . "$SCHEMA" >/dev/null
}

@test "schema declares draft-07 and object type" {
    [ "$(jq -r '."$schema"' "$SCHEMA")" = "http://json-schema.org/draft-07/schema#" ]
    [ "$(jq -r '.type' "$SCHEMA")" = "object" ]
}

@test "schema defines exactly the 16 answer fields" {
    run jq -r '.properties | keys | join(" ")' "$SCHEMA"
    [ "$status" -eq 0 ]
    [ "$output" = "domain domainAliases hostHttpPort hostHttpsPort hostPgAdminPort hostSshPort hostVitePort memoryLimit nodeServiceBlock pgClientVersion phpFpmIncludeNode phpVersion postMaxSize schemaVersion timezone uploadMaxFilesize" ]
}

@test "required lists the four mandatory fields" {
    run jq -c '.required' "$SCHEMA"
    [ "$output" = '["schemaVersion","phpVersion","pgClientVersion","domain"]' ]
}

@test "schemaVersion is const 1" {
    [ "$(jq -r '.properties.schemaVersion.const' "$SCHEMA")" = "1" ]
}

@test "phpVersion is a string with version pattern" {
    [ "$(jq -r '.properties.phpVersion.type' "$SCHEMA")" = "string" ]
    [ "$(jq -r '.properties.phpVersion.pattern' "$SCHEMA")" = '^[0-9]+\.[0-9]+(\.[0-9]+)?$' ]
}

@test "pgClientVersion is an integer, minimum 14" {
    [ "$(jq -r '.properties.pgClientVersion.type' "$SCHEMA")" = "integer" ]
    [ "$(jq -r '.properties.pgClientVersion.minimum' "$SCHEMA")" = "14" ]
}

@test "domain is a string with minLength 1" {
    [ "$(jq -r '.properties.domain.type' "$SCHEMA")" = "string" ]
    [ "$(jq -r '.properties.domain.minLength' "$SCHEMA")" = "1" ]
}

@test "size fields are strings with ^[0-9]+[MG]\$ pattern" {
    for f in memoryLimit uploadMaxFilesize postMaxSize; do
        [ "$(jq -r ".properties.${f}.type" "$SCHEMA")" = "string" ]
        [ "$(jq -r ".properties.${f}.pattern" "$SCHEMA")" = '^[0-9]+[MG]$' ]
    done
}

@test "string fields domainAliases, timezone, nodeServiceBlock are strings" {
    for f in domainAliases timezone nodeServiceBlock; do
        [ "$(jq -r ".properties.${f}.type" "$SCHEMA")" = "string" ]
    done
}

@test "phpFpmIncludeNode is boolean" {
    [ "$(jq -r '.properties.phpFpmIncludeNode.type' "$SCHEMA")" = "boolean" ]
}

@test "port fields are integers 1..65535" {
    [ "$(jq -r '.properties.hostVitePort.default' "$SCHEMA")" = "5173" ]
    for f in hostHttpPort hostHttpsPort hostSshPort hostPgAdminPort hostVitePort; do
        [ "$(jq -r ".properties.${f}.type" "$SCHEMA")" = "integer" ]
        [ "$(jq -r ".properties.${f}.minimum" "$SCHEMA")" = "1" ]
        [ "$(jq -r ".properties.${f}.maximum" "$SCHEMA")" = "65535" ]
    done
}
