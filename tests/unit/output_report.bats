#!/usr/bin/env bats
# T027 — print_env_fragment() and print_summary() (tech §15)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
    TMP="$(mktemp -d)"
    OUT_DIR="$TMP/out"
    STAGE_DIR="$TMP/stage"
    mkdir -p "$OUT_DIR" "$STAGE_DIR"
    FORCE=false
    WRITTEN_FILES=()
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    validate_answers
}

teardown() {
    rm -rf "$TMP"
}

@test "print_env_fragment: emits NGINX_SERVER_NAME from domain" {
    set -e
    run print_env_fragment
    [ "$status" -eq 0 ]
    [[ "$output" == *"NGINX_SERVER_NAME=${ANSWERS[domain]}"* ]]
}

@test "print_env_fragment: emits configured ports and alias" {
    set -e
    ANSWERS[hostHttpPort]=8088
    ANSWERS[hostHttpsPort]=8444
    ANSWERS[domainAliases]="www.example.test"
    run print_env_fragment
    [[ "$output" == *"NGINX_HOST_HTTP_PORT=8088"* ]]
    [[ "$output" == *"NGINX_HOST_HTTPS_PORT=8444"* ]]
    [[ "$output" == *"NGINX_SERVER_ALIAS=www.example.test"* ]]
}

@test "print_env_fragment: leaves no unsubstituted {{ }} tokens" {
    set -e
    run print_env_fragment
    [[ "$output" != *"{{"* ]]
}

@test "print_env_fragment: prints DB/PGADMIN NOTE reminder after the env block" {
    set -e
    run print_env_fragment
    [[ "$output" == *"NOTE:"* ]]
    [[ "$output" == *"DB_CONNECTION=pgsql"* ]]
    [[ "$output" == *"PGADMIN_DEFAULT_EMAIL"* ]]
    local before="${output%%NOTE:*}"
    [[ "$before" == *"NGINX_SERVER_NAME="* ]]
}

@test "print_env_fragment: does not leak TOKEN_ variables into the caller" {
    set -e
    unset TOKEN_HOST_HTTP_PORT TOKEN_NGINX_SERVER_NAME || true
    print_env_fragment >/dev/null
    [ -z "${TOKEN_NGINX_SERVER_NAME:-}" ]
}

@test "commit_staged: records each written file in WRITTEN_FILES" {
    set -e
    resolve_blocks
    export_tokens
    stage_files >/dev/null
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    [ "${#WRITTEN_FILES[@]}" -eq 15 ]
    [[ " ${WRITTEN_FILES[*]} " == *" sail "* ]]
}

@test "print_summary: lists every written file plus docker.answers.json" {
    set -e
    WRITTEN_FILES=("docker-compose.yml" "sail" "docker/nginx/Dockerfile")
    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker-compose.yml"* ]]
    [[ "$output" == *"sail"* ]]
    [[ "$output" == *"docker/nginx/Dockerfile"* ]]
    [[ "$output" == *"docker.answers.json"* ]]
}
