#!/usr/bin/env bats
# T026 — commit_staged() and file permissions (tech §13)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
    set +e
    TMP="$(mktemp -d)"
    OUT_DIR="$TMP/out"
    STAGE_DIR="$TMP/stage"
    mkdir -p "$OUT_DIR" "$STAGE_DIR"
    FORCE=false
    load_answers "${REPO_ROOT}/examples/full.answers.json"
    validate_answers
    resolve_blocks
    export_tokens
    stage_files >/dev/null
}

teardown() {
    rm -rf "$TMP"
}

@test "commit_staged: writes all 15 staged files to OUT_DIR at correct paths" {
    set -e
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    local n
    n=$(cd "$STAGE_DIR" && find . -type f | wc -l)
    [ "$n" -eq 15 ]
    while IFS= read -r f; do
        [ -f "$OUT_DIR/${f#./}" ]
        cmp "$STAGE_DIR/${f#./}" "$OUT_DIR/${f#./}"
    done < <(cd "$STAGE_DIR" && find . -type f)
}

@test "commit_staged: sail, generate-keys.sh, startup.sh, docker-entrypoint.sh are executable" {
    set -e
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    [ -x "$OUT_DIR/sail" ]
    [ -x "$OUT_DIR/docker/nginx/ssl/generate-keys.sh" ]
    [ -x "$OUT_DIR/docker/nginx/startup.sh" ]
    [ -x "$OUT_DIR/docker/php-fpm/docker-entrypoint.sh" ]
}

@test "commit_staged: executables are chmod +x even if staged copy lost the bit" {
    set -e
    chmod -x "$STAGE_DIR/sail" "$STAGE_DIR/docker/nginx/startup.sh"
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    [ -x "$OUT_DIR/sail" ]
    [ -x "$OUT_DIR/docker/nginx/startup.sh" ]
}

@test "commit_staged: second run with no edits writes no .new files" {
    set -e
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    [ -z "$(find "$OUT_DIR" -name '*.new')" ]
}

@test "commit_staged: hand-edited generated file -> .new sibling, original untouched" {
    set -e
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    echo "# my edit" >> "$OUT_DIR/docker-compose.yml"
    cp "$OUT_DIR/docker-compose.yml" "$TMP/edited"
    run commit_staged "$STAGE_DIR" "$OUT_DIR"
    [ "$status" -eq 0 ]
    [ -f "$OUT_DIR/docker-compose.yml.new" ]
    cmp "$STAGE_DIR/docker-compose.yml" "$OUT_DIR/docker-compose.yml.new"
    cmp "$TMP/edited" "$OUT_DIR/docker-compose.yml"
}

@test "commit_staged: --force overwrites hand-edited file with no .new" {
    set -e
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    echo "# my edit" >> "$OUT_DIR/docker-compose.yml"
    FORCE=true
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    [ ! -e "$OUT_DIR/docker-compose.yml.new" ]
    cmp "$STAGE_DIR/docker-compose.yml" "$OUT_DIR/docker-compose.yml"
}

@test "commit_staged: invariant files are always overwritten, never .new" {
    set -e
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    echo "# my edit" >> "$OUT_DIR/docker/nginx/nginx.conf"
    commit_staged "$STAGE_DIR" "$OUT_DIR" >/dev/null
    [ ! -e "$OUT_DIR/docker/nginx/nginx.conf.new" ]
    cmp "$STAGE_DIR/docker/nginx/nginx.conf" "$OUT_DIR/docker/nginx/nginx.conf"
}
