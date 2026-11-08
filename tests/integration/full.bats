#!/usr/bin/env bats
# Integration — full.answers.json (nodeServiceBlock=builtin, phpFpmIncludeNode=false)
# (tech §20: full.bats)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TEST_OUT="$(mktemp -d)"
    "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}" >/dev/null
}

teardown() {
    rm -rf "${TEST_OUT}"
}

@test "full: exits 0" {
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "${TEST_OUT}"
    [ "$status" -eq 0 ]
}

@test "full: docker-compose.yml contains node:20-alpine" {
    grep -qF 'node:20-alpine' "${TEST_OUT}/docker-compose.yml"
}

@test "full: no triple blank lines in any generated file" {
    for f in docker-compose.yml docker/php-fpm/Dockerfile docker/php-fpm/laravel.ini; do
        ! grep -qP '\n\n\n' "${TEST_OUT}/${f}" 2>/dev/null || ! perl -0777 -e 'exit 1 if /\n{3,}/' "${TEST_OUT}/${f}"
    done
}

@test "full: php-fpm Dockerfile does NOT contain nodejs/npm apt install line" {
    ! grep -q 'nodejs npm' "${TEST_OUT}/docker/php-fpm/Dockerfile"
}

@test "full: no unsubstituted {{HOST_ tokens in any file" {
    ! grep -rqE '\{\{HOST_' "${TEST_OUT}"
}

@test "full: FROM php:8.5-fpm in Dockerfile" {
    grep -qxF 'FROM php:8.5-fpm' "${TEST_OUT}/docker/php-fpm/Dockerfile"
}

@test "full: memory_limit = 256M in laravel.ini" {
    grep -qxF 'memory_limit = 256M' "${TEST_OUT}/docker/php-fpm/laravel.ini"
}

@test "full: date.timezone=America/New_York in laravel.ini" {
    grep -qxF 'date.timezone=America/New_York' "${TEST_OUT}/docker/php-fpm/laravel.ini"
}

@test "full: opcache.jit=tracing present in laravel.ini" {
    grep -qxF 'opcache.jit=tracing' "${TEST_OUT}/docker/php-fpm/laravel.ini"
}

@test "full: opcache.enable_cli is absent from laravel.ini (entrypoint injects it)" {
    ! grep -qE '^opcache\.enable_cli' "${TEST_OUT}/docker/php-fpm/laravel.ini"
}
