#!/usr/bin/env bats
# T028 — main() end-to-end (tech §16)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TMP="$(mktemp -d)"
    OUT="$TMP/out"
    mkdir -p "$OUT"
}

teardown() {
    rm -rf "$TMP"
}

@test "main: full answers exits 0 and writes all 17 output paths" {
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT"
    [ "$status" -eq 0 ]
    local n
    n=$(find "$OUT" -type f | wc -l)
    [ "$n" -eq 17 ]
    [ -f "$OUT/docker-compose.yml" ]
    [ -f "$OUT/sail" ]
    [ -f "$OUT/docker/php-fpm/Dockerfile" ]
    [ -f "$OUT/docker/php-fpm/laravel.ini" ]
    [ -f "$OUT/docker/logs/nginx/.gitkeep" ]
    [ -f "$OUT/.gitignore" ]
}

@test "main: docker.answers.json is valid JSON matching input" {
    "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT" >/dev/null
    jq -e . "$OUT/docker.answers.json" >/dev/null
    [ "$(jq -S -c . "$OUT/docker.answers.json")" = "$(jq -S -c . "${REPO_ROOT}/examples/full.answers.json")" ]
}

@test "main: generated files have header, invariant files do not" {
    "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT" >/dev/null
    [[ "$(sed -n 2p "$OUT/docker-compose.yml")" =~ Hash:\ [0-9a-f]{64} ]]
    ! grep -q 'Hash: [0-9a-f]\{64\}' "$OUT/sail"
    ! grep -q 'Hash: [0-9a-f]\{64\}' "$OUT/docker/nginx/Dockerfile"
}

@test "main: prints env fragment and DB/PGADMIN reminder; sail executable" {
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Add the following settings to your project's .env file:"* ]]
    [[ "$output" == *"NGINX_SERVER_NAME=myapp.com"* ]]
    [[ "$output" == *"NOTE:"* ]]
    [ -x "$OUT/sail" ]
}

@test "main: second run after hand edit writes .new and leaves original" {
    "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT" >/dev/null
    echo "# edit" >> "$OUT/docker-compose.yml"
    run "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT"
    [ "$status" -eq 0 ]
    [ -f "$OUT/docker-compose.yml.new" ]
    tail -n1 "$OUT/docker-compose.yml" | grep -q '# edit'
}

@test "main: no staging dir left behind" {
    local before after
    before=$(ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | wc -l)
    "${REPO_ROOT}/generate.sh" --answers "${REPO_ROOT}/examples/full.answers.json" --out-dir "$OUT" >/dev/null
    after=$(ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | wc -l)
    [ "$after" -le "$before" ]
}
