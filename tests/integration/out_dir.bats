#!/usr/bin/env bats
# Integration — --out-dir creation (T033; tech §4: --out-dir)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TEST_OUT="$(mktemp -d)"
}

teardown() {
    rm -rf "${TEST_OUT}"
}

@test "out_dir: missing nested --out-dir is created and all 16 outputs are written" {
    local target="${TEST_OUT}/new/nested"
    [ ! -e "$target" ]
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/minimal.answers.json" --out-dir "$target"
    [ "$status" -eq 0 ]
    [ -d "$target" ]
    local expected=(
        docker-compose.yml
        sail
        docker/nginx/Dockerfile
        docker/nginx/nginx.conf
        docker/nginx/startup.sh
        docker/nginx/logrotate/nginx
        docker/nginx/sites/laravel.conf
        docker/nginx/ssl/.gitignore
        docker/nginx/ssl/generate-keys.sh
        docker/php-fpm/Dockerfile
        docker/php-fpm/laravel.ini
        docker/php-fpm/php-fpm-pool.conf
        docker/php-fpm/docker-entrypoint.sh
        docker/logs/nginx/.gitkeep
        docker/logs/php-fpm/.gitkeep
        docker.answers.json
    )
    local f
    for f in "${expected[@]}"; do
        [ -f "${target}/${f}" ] || { echo "missing: $f"; false; }
    done
}

@test "out_dir: pre-existing --out-dir still works" {
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/minimal.answers.json" --out-dir "${TEST_OUT}"
    [ "$status" -eq 0 ]
    [ -f "${TEST_OUT}/docker.answers.json" ]
}

@test "out_dir: uncreatable --out-dir exits 1 with an error message" {
    : > "${TEST_OUT}/blocker"
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/minimal.answers.json" --out-dir "${TEST_OUT}/blocker/sub"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: cannot create output directory: ${TEST_OUT}/blocker/sub"* ]]
}

@test "out_dir: --help does not create --out-dir" {
    run "${REPO_ROOT}/generate.sh" --out-dir "${TEST_OUT}/never" --help
    [ "$status" -eq 0 ]
    [ ! -e "${TEST_OUT}/never" ]
}
