#!/usr/bin/env bats
# T01 — repository directory structure and .gitignore (functional-spec §3, §11)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
}

@test "directory templates/snippets exists" {
    [ -d "${REPO_ROOT}/templates/snippets" ]
}

@test "directory templates/docker/nginx/ssl exists" {
    [ -d "${REPO_ROOT}/templates/docker/nginx/ssl" ]
}

@test "directory templates/docker/nginx/logrotate exists" {
    [ -d "${REPO_ROOT}/templates/docker/nginx/logrotate" ]
}

@test "directory templates/docker/nginx/sites exists" {
    [ -d "${REPO_ROOT}/templates/docker/nginx/sites" ]
}

@test "directory templates/docker/php-fpm exists" {
    [ -d "${REPO_ROOT}/templates/docker/php-fpm" ]
}

@test "directory examples exists" {
    [ -d "${REPO_ROOT}/examples" ]
}

@test "directory schema exists" {
    [ -d "${REPO_ROOT}/schema" ]
}

@test ".gitignore excludes .DS_Store" {
    grep -qxF '.DS_Store' "${REPO_ROOT}/.gitignore"
}

@test ".gitignore excludes *.new conflict files" {
    grep -qxF '*.new' "${REPO_ROOT}/.gitignore"
}

@test ".gitignore excludes editor swap files" {
    grep -qxF '*.swp' "${REPO_ROOT}/.gitignore"
    grep -qxF '*.swo' "${REPO_ROOT}/.gitignore"
    grep -qxF '*~' "${REPO_ROOT}/.gitignore"
}
