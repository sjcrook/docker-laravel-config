#!/usr/bin/env bats
# T13 — templates/sail (functional-spec §8.9)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SAIL="${REPO_ROOT}/templates/sail"
}

@test "sail: exists" {
    [ -f "$SAIL" ]
}

@test "sail: first line is #!/usr/bin/env bash" {
    [ "$(head -n1 "$SAIL")" = '#!/usr/bin/env bash' ]
}

@test "sail: derives container name from basename of PWD, no zsh-isms" {
    grep -qxF 'CONTAINER_NAME="$(basename "$PWD")-php-fpm-1"' "$SAIL"
    ! grep -qF '${PWD:t}' "$SAIL"
}

@test "sail: docker exec into the Laravel dir with the dummy \"\$@\" pattern" {
    grep -qF 'docker exec -i $TTY_FLAG -w /var/www/laravel/current "$CONTAINER_NAME"' "$SAIL"
    grep -qF "bash -c 'set -x; exec \"\$@\"' dummy \"\$@\"" "$SAIL"
}

@test "sail: has usage examples in comments" {
    grep -qF '#   ./sail php artisan migrate' "$SAIL"
    grep -qF '#   ./sail composer require vendor/package' "$SAIL"
}

@test "sail: contains no tokens" {
    ! grep -qE '\{\{[A-Z_]+\}\}' "$SAIL"
}

@test "sail: passes bash -n syntax check" {
    bash -n "$SAIL"
}
