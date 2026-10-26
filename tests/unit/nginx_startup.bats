#!/usr/bin/env bats
# T04 — behavioural tests: run templates/docker/nginx/startup.sh for real against a scratch
# /etc/nginx (via NGINX_ETC_DIR) with nginx/crond/crontab stubbed on PATH.
# Requires openssl and envsubst on the host (GNU gettext).

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    NGINX_DIR="${REPO_ROOT}/templates/docker/nginx"
    TEST_TMP="$(mktemp -d)"

    FAKE_ETC="${TEST_TMP}/etc-nginx"
    STUBS="${TEST_TMP}/stubs"
    mkdir -p "${FAKE_ETC}/ssl" "${FAKE_ETC}/sites-available" "${STUBS}"
    cp "${NGINX_DIR}/sites/laravel.conf" "${FAKE_ETC}/sites-available/laravel.conf"

    export CRON_FILE="${TEST_TMP}/crontab.txt"
    export NGINX_CALLS="${TEST_TMP}/nginx-calls.txt"
    : > "${NGINX_CALLS}"

    cat > "${STUBS}/crontab" <<'STUB'
#!/bin/bash
if [ "$1" = "-l" ]; then
    if [ -f "${CRON_FILE}" ]; then cat "${CRON_FILE}"; else echo "no crontab for root" >&2; exit 1; fi
else
    # Like the real crontab: read all of stdin before replacing the file (the caller
    # pipes `crontab -l` output through us, so truncating early would race with it).
    new="$(cat)"
    printf '%s\n' "${new}" > "${CRON_FILE}"
fi
STUB
    printf '#!/bin/bash\nexit 0\n' > "${STUBS}/crond"
    printf '#!/bin/bash\necho "$*" >> "${NGINX_CALLS}"\nexit 0\n' > "${STUBS}/nginx"
    chmod +x "${STUBS}/crontab" "${STUBS}/crond" "${STUBS}/nginx"

    unset NGINX_SERVER_NAME NGINX_SERVER_ALIAS
}

teardown() {
    rm -rf "${TEST_TMP}"
}

run_startup() {
    PATH="${STUBS}:${PATH}" NGINX_ETC_DIR="${FAKE_ETC}" run bash "${NGINX_DIR}/startup.sh"
}

place_existing_cert() {
    echo "cert" > "${FAKE_ETC}/ssl/default.crt"
    echo "key"  > "${FAKE_ETC}/ssl/default.key"
}

@test "startup.sh run: exits non-zero with a clear message when NGINX_SERVER_NAME is unset" {
    run_startup
    [ "$status" -ne 0 ]
    [[ "$output" == *NGINX_SERVER_NAME* ]]
}

@test "startup.sh run: fallback cert has SANs for the domain, every alias, localhost and loopback" {
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS="www.app.test api.app.test"
    run_startup
    [ "$status" -eq 0 ]
    [ -f "${FAKE_ETC}/ssl/default.crt" ]
    [ -f "${FAKE_ETC}/ssl/default.key" ]
    local san
    san="$(openssl x509 -in "${FAKE_ETC}/ssl/default.crt" -noout -ext subjectAltName)"
    [[ "$san" == *"DNS:app.test"* ]]
    [[ "$san" == *"DNS:www.app.test"* ]]
    [[ "$san" == *"DNS:api.app.test"* ]]
    [[ "$san" == *"DNS:localhost"* ]]
    [[ "$san" == *"IP Address:127.0.0.1"* ]]
}

@test "startup.sh run: fallback cert works when NGINX_SERVER_ALIAS is empty" {
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    run openssl x509 -in "${FAKE_ETC}/ssl/default.crt" -noout -ext subjectAltName
    [[ "$output" == *"DNS:app.test"* ]]
}

@test "startup.sh run: fallback cert works when NGINX_SERVER_ALIAS is unset" {
    export NGINX_SERVER_NAME="app.test"
    run_startup
    [ "$status" -eq 0 ]
    [ -f "${FAKE_ETC}/ssl/default.crt" ]
}

@test "startup.sh run: fallback key is mode 644" {
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    [ "$(ls -l "${FAKE_ETC}/ssl/default.key" | cut -c1-10)" = "-rw-r--r--" ]
}

@test "startup.sh run: an existing cert and key are left untouched" {
    place_existing_cert
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    [ "$(cat "${FAKE_ETC}/ssl/default.crt")" = "cert" ]
    [ "$(cat "${FAKE_ETC}/ssl/default.key")" = "key" ]
}

@test "startup.sh run: a cert without its key is regenerated rather than left half-configured" {
    echo "cert-only" > "${FAKE_ETC}/ssl/default.crt"
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    [ -f "${FAKE_ETC}/ssl/default.key" ]
    [ "$(cat "${FAKE_ETC}/ssl/default.crt")" != "cert-only" ]
}

@test "startup.sh run: renders server_name into sites-enabled/ and leaves nginx variables intact" {
    place_existing_cert
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS="www.app.test api.app.test"
    run_startup
    [ "$status" -eq 0 ]
    local rendered="${FAKE_ETC}/sites-enabled/laravel.conf"
    [ -f "${rendered}" ]
    grep -qF 'server_name app.test www.app.test api.app.test;' "${rendered}"
    grep -qF 'try_files $uri $uri/ /index.php?$query_string;' "${rendered}"
    grep -qF '$realpath_root$fastcgi_script_name' "${rendered}"
    run grep -F '${NGINX_' "${rendered}"
    [ "$status" -eq 1 ]
}

@test "startup.sh run: never modifies the bind-mounted sites-available/ source" {
    place_existing_cert
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    cmp "${NGINX_DIR}/sites/laravel.conf" "${FAKE_ETC}/sites-available/laravel.conf"
}

@test "startup.sh run: a domain change on restart is picked up and stale confs are removed" {
    place_existing_cert
    mkdir -p "${FAKE_ETC}/sites-enabled"
    echo "stale" > "${FAKE_ETC}/sites-enabled/removed-site.conf"
    export NGINX_SERVER_NAME="one.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    export NGINX_SERVER_NAME="two.test"
    run_startup
    [ "$status" -eq 0 ]
    grep -qF 'server_name two.test ;' "${FAKE_ETC}/sites-enabled/laravel.conf"
    run grep -F 'one.test' "${FAKE_ETC}/sites-enabled/laravel.conf"
    [ "$status" -eq 1 ]
    [ ! -e "${FAKE_ETC}/sites-enabled/removed-site.conf" ]
}

@test "startup.sh run: succeeds with an empty sites-available directory" {
    place_existing_cert
    rm -f "${FAKE_ETC}/sites-available/"*.conf
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
}

@test "startup.sh run: installs exactly one 4-hourly reload cron entry, even across restarts" {
    place_existing_cert
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    run_startup
    run_startup
    [ "$status" -eq 0 ]
    [ "$(grep -cF '0 */4 * * * nginx -s reload' "${CRON_FILE}")" -eq 1 ]
}

@test "startup.sh run: preserves pre-existing crontab entries" {
    place_existing_cert
    echo '0 2 * * * run-parts /etc/periodic/daily' > "${CRON_FILE}"
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    grep -qF '0 2 * * * run-parts /etc/periodic/daily' "${CRON_FILE}"
    grep -qF '0 */4 * * * nginx -s reload' "${CRON_FILE}"
}

@test "startup.sh run: validates the config with nginx -t, then starts nginx" {
    place_existing_cert
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -eq 0 ]
    [ "$(sed -n 1p "${NGINX_CALLS}")" = "-t" ]
    [ "$(wc -l < "${NGINX_CALLS}" | tr -d ' ')" -eq 2 ]
}

@test "startup.sh run: aborts without starting nginx when nginx -t fails" {
    place_existing_cert
    printf '#!/bin/bash\necho "$*" >> "${NGINX_CALLS}"\n[ "$1" = "-t" ] && exit 1\nexit 0\n' > "${STUBS}/nginx"
    export NGINX_SERVER_NAME="app.test" NGINX_SERVER_ALIAS=""
    run_startup
    [ "$status" -ne 0 ]
    [ "$(wc -l < "${NGINX_CALLS}" | tr -d ' ')" -eq 1 ]
}
