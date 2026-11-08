#!/usr/bin/env bats
# T22 — export_tokens() and render_template() (tech §11)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
    TMP="$(mktemp -d)"
    OUT_DIR="$TMP"
    # Start each test with no TOKEN_* variables leaking in from the environment.
    local v
    for v in $(compgen -e | grep '^TOKEN_' || true); do unset "$v"; done
}

teardown() {
    rm -rf "$TMP"
}

@test "export_tokens: exports all 10 scalar tokens from ANSWERS" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    export_tokens
    [ "$TOKEN_PHP_VERSION" = "8.5" ]
    [ "$TOKEN_PG_CLIENT_VERSION" = "18" ]
    [ "$TOKEN_MEMORY_LIMIT" = "256M" ]
    [ "$TOKEN_UPLOAD_MAX_FILESIZE" = "64M" ]
    [ "$TOKEN_POST_MAX_SIZE" = "64M" ]
    [ "$TOKEN_TIMEZONE" = "America/New_York" ]
    [ "$TOKEN_HOST_HTTP_PORT" = "80" ]
    [ "$TOKEN_HOST_HTTPS_PORT" = "443" ]
    [ "$TOKEN_HOST_SSH_PORT" = "2222" ]
    [ "$TOKEN_HOST_PGADMIN_PORT" = "8081" ]
}

@test "export_tokens: tokens are visible to child processes" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    export_tokens
    run bash -c 'echo "$TOKEN_PHP_VERSION"'
    [ "$output" = "8.5" ]
}

@test "render_template: single token replaced" {
    set -e
    export TOKEN_PHP_VERSION="8.4"
    printf 'FROM php:{{PHP_VERSION}}-fpm\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = "FROM php:8.4-fpm" ]
}

@test "render_template: all 10 scalar tokens replaced" {
    set -e
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    export_tokens
    printf '%s\n' '{{PHP_VERSION}} {{PG_CLIENT_VERSION}} {{MEMORY_LIMIT}} {{UPLOAD_MAX_FILESIZE}} {{POST_MAX_SIZE}} {{TIMEZONE}} {{HOST_HTTP_PORT}} {{HOST_HTTPS_PORT}} {{HOST_SSH_PORT}} {{HOST_PGADMIN_PORT}}' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = "8.5 18 256M 64M 64M America/New_York 80 443 2222 8081" ]
}

@test "render_template: non-token content unchanged" {
    set -e
    export TOKEN_PHP_VERSION="8.4"
    printf 'a ${VAR} {{UNKNOWN}} \\ $x\n\nb\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = "$(cat "$TMP/src")" ]
}

@test "render_template: empty token collapses blank lines (no triple-blank sequences)" {
    set -e
    export TOKEN_NODE_SERVICE_BLOCK=""
    printf 'a\n\n{{NODE_SERVICE_BLOCK}}\n\nb\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    ! grep -Pzo '\n\n\n' "$TMP/dst" > /dev/null
    [ "$(cat "$TMP/dst")" = $'a\n\nb' ]
}

@test "render_template: slashes in value pass through" {
    set -e
    export TOKEN_TIMEZONE="America/New_York"
    printf 'tz={{TIMEZONE}}\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = "tz=America/New_York" ]
}

@test "render_template: ampersands in value pass through" {
    set -e
    export TOKEN_MEMORY_LIMIT='a&b&&c \1 $1'
    printf 'm={{MEMORY_LIMIT}}\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = 'm=a&b&&c \1 $1' ]
}

@test "render_template: multi-line block token renders correctly (newlines preserved)" {
    set -e
    export TOKEN_NODE_SERVICE_BLOCK=$'  node:\n    image: node:20-alpine\n    entrypoint: [""]'
    printf 'services:\n{{NODE_SERVICE_BLOCK}}\nnetworks:\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = $'services:\n  node:\n    image: node:20-alpine\n    entrypoint: [""]\nnetworks:' ]
}

@test "render_template: file with no tokens written unchanged" {
    set -e
    export TOKEN_PHP_VERSION="8.4"
    printf 'nothing to see\nhere\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    cmp "$TMP/src" "$TMP/dst"
}

@test "render_template: creates missing destination directory" {
    set -e
    printf 'x\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/deep/er/dst"
    [ -f "$TMP/deep/er/dst" ]
}

@test "render_template: replaces every occurrence of a token" {
    set -e
    export TOKEN_HOST_HTTP_PORT="8080"
    printf '{{HOST_HTTP_PORT}}:80 {{HOST_HTTP_PORT}}\n' > "$TMP/src"
    render_template "$TMP/src" "$TMP/dst"
    [ "$(cat "$TMP/dst")" = "8080:80 8080" ]
}
