#!/usr/bin/env bats
# T07 — templates/docker/nginx/ssl/ (.gitignore + generate-keys.sh), functional-spec §8.5

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SSL_DIR="${REPO_ROOT}/templates/docker/nginx/ssl"
    WORK="$(mktemp -d)"
}

teardown() {
    rm -rf "${WORK}"
}

# Copy the script into a scratch dir (it writes certs next to itself) and put a
# stub mkcert on PATH that records its arguments and creates the two output files.
install_stub_mkcert() {
    mkdir -p "${WORK}/bin" "${WORK}/ssl"
    cp "${SSL_DIR}/generate-keys.sh" "${WORK}/ssl/generate-keys.sh"
    cat > "${WORK}/bin/mkcert" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "${MKCERT_ARGS_FILE}"
while [ $# -gt 0 ]; do
    case "$1" in
        -cert-file) : > "$2"; shift 2 ;;
        -key-file)  : > "$2"; chmod 600 "$2"; shift 2 ;;
        *) shift ;;
    esac
done
EOF
    chmod +x "${WORK}/bin/mkcert"
    export MKCERT_ARGS_FILE="${WORK}/mkcert.args"
}

# ---- .gitignore --------------------------------------------------------------

@test "ssl/.gitignore: excludes *.crt *.key *.csr *.pem" {
    for pattern in '*.crt' '*.key' '*.csr' '*.pem'; do
        grep -qxF "${pattern}" "${SSL_DIR}/.gitignore"
    done
}

# ---- generate-keys.sh (static) -----------------------------------------------

@test "generate-keys.sh: starts with #!/bin/bash, has valid syntax, is executable" {
    [ "$(head -n1 "${SSL_DIR}/generate-keys.sh")" = '#!/bin/bash' ]
    bash -n "${SSL_DIR}/generate-keys.sh"
    [ -x "${SSL_DIR}/generate-keys.sh" ]
}

@test "generate-keys.sh: detects mkcert via command -v" {
    grep -qF 'command -v mkcert' "${SSL_DIR}/generate-keys.sh"
}

@test "generate-keys.sh: has no hardcoded project domains or {{TOKEN}} placeholders" {
    run grep -E 'ipresenttoyou|cryptotrends' "${SSL_DIR}/generate-keys.sh"
    [ "$status" -eq 1 ]
    run grep -F '{{' "${SSL_DIR}/generate-keys.sh"
    [ "$status" -eq 1 ]
}

# ---- generate-keys.sh (behaviour, stubbed mkcert) -----------------------------

@test "generate-keys.sh: exits 1 with usage when no domain is given" {
    install_stub_mkcert
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
    [ ! -e "${MKCERT_ARGS_FILE}" ]
}

@test "generate-keys.sh: exits 1 with usage when the domain is an empty string" {
    install_stub_mkcert
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh" ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "generate-keys.sh: exits 1 with an install hint when mkcert is missing" {
    mkdir -p "${WORK}/ssl"
    cp "${SSL_DIR}/generate-keys.sh" "${WORK}/ssl/generate-keys.sh"
    PATH="/usr/bin:/bin" run "${WORK}/ssl/generate-keys.sh" myapp.local
    [ "$status" -eq 1 ]
    [[ "$output" == *"mkcert not found"* ]]
    [[ "$output" == *"mkcert -install"* ]]
}

@test "generate-keys.sh: writes default.crt and default.key next to the script, not the cwd" {
    install_stub_mkcert
    cd "${WORK}"
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh" myapp.local
    [ "$status" -eq 0 ]
    [ -f "${WORK}/ssl/default.crt" ]
    [ -f "${WORK}/ssl/default.key" ]
    [ ! -e "${WORK}/default.crt" ]
}

@test "generate-keys.sh: passes domain, aliases, then localhost 127.0.0.1 ::1 to mkcert" {
    install_stub_mkcert
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh" myapp.local www.myapp.local test.myapp.local
    [ "$status" -eq 0 ]
    # Names are everything after the -cert-file/-key-file pairs (last 6 args).
    names="$(tail -n 6 "${MKCERT_ARGS_FILE}" | tr '\n' ' ')"
    [ "${names}" = "myapp.local www.myapp.local test.myapp.local localhost 127.0.0.1 ::1 " ] || {
        echo "got: ${names}"; return 1
    }
}

@test "generate-keys.sh: with no aliases still includes localhost 127.0.0.1 ::1" {
    install_stub_mkcert
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh" myapp.local
    [ "$status" -eq 0 ]
    names="$(tail -n 4 "${MKCERT_ARGS_FILE}" | tr '\n' ' ')"
    [ "${names}" = "myapp.local localhost 127.0.0.1 ::1 " ]
}

@test "generate-keys.sh: chmod 644 on default.key so the nginx container can read it" {
    install_stub_mkcert
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh" myapp.local
    [ "$status" -eq 0 ]
    [ "$(stat -c '%a' "${WORK}/ssl/default.key" 2>/dev/null || stat -f '%Lp' "${WORK}/ssl/default.key")" = "644" ]
}

@test "generate-keys.sh: exits non-zero and does not chmod when mkcert fails" {
    install_stub_mkcert
    printf '#!/bin/bash\nexit 3\n' > "${WORK}/bin/mkcert"
    PATH="${WORK}/bin:${PATH}" run "${WORK}/ssl/generate-keys.sh" myapp.local
    [ "$status" -ne 0 ]
    [[ "$output" != *"Done."* ]]
}
