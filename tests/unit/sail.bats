#!/usr/bin/env bats
# T039 — templates/sail TTY detection (functional-spec §8.9)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SAIL="${REPO_ROOT}/templates/sail"
}

@test "sail tty: shebang is #!/usr/bin/env bash" {
    [ "$(head -n1 "$SAIL")" = '#!/usr/bin/env bash' ]
}

@test "sail tty: TTY_FLAG is initialised empty" {
    grep -qxF 'TTY_FLAG=""' "$SAIL"
}

@test "sail tty: TTY_FLAG set to -t only when stdin is a terminal" {
    grep -qxF '[ -t 0 ] && TTY_FLAG="-t"' "$SAIL"
}

@test "sail tty: docker exec uses -i \$TTY_FLAG -w" {
    grep -qF 'docker exec -i $TTY_FLAG -w' "$SAIL"
}

@test "sail tty: old 'docker exec -i -w' form is absent" {
    ! grep -qF 'docker exec -i -w' "$SAIL"
}

@test "sail tty: container name derived via basename \"\$PWD\"" {
    grep -qF 'basename "$PWD"' "$SAIL"
}
