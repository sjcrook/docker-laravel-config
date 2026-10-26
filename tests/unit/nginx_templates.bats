#!/usr/bin/env bats
# T02, T03 — invariant nginx templates: Dockerfile and nginx.conf (functional-spec §8.2)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    NGINX_DIR="${REPO_ROOT}/templates/docker/nginx"
}

# ---- T02: Dockerfile -------------------------------------------------------

@test "nginx Dockerfile: base image is nginx:alpine" {
    grep -qE '^FROM nginx:alpine$' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: installs logrotate openssl bash curl" {
    grep -qE 'apk add .*logrotate' "${NGINX_DIR}/Dockerfile"
    grep -qE 'apk add .*openssl' "${NGINX_DIR}/Dockerfile"
    grep -qE 'apk add .*\bbash\b' "${NGINX_DIR}/Dockerfile"
    grep -qE 'apk add .*\bcurl\b' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: fails the build if envsubst is missing from the base image" {
    grep -qE 'command -v envsubst' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: ensures www-data exists as GID/UID 82 without masking real errors" {
    grep -qE 'addgroup -g 82 -S www-data' "${NGINX_DIR}/Dockerfile"
    grep -qE 'adduser -u 82 -D -S -G www-data www-data' "${NGINX_DIR}/Dockerfile"
    grep -qE 'getent group www-data' "${NGINX_DIR}/Dockerfile"
    grep -qE 'getent passwd www-data' "${NGINX_DIR}/Dockerfile"
    run grep -E '\|\| true|2>/dev/null' "${NGINX_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "nginx Dockerfile: upstream container/port are build ARGs defaulting to php-fpm / 9000" {
    grep -qxF 'ARG PHP_UPSTREAM_CONTAINER=php-fpm' "${NGINX_DIR}/Dockerfile"
    grep -qxF 'ARG PHP_UPSTREAM_PORT=9000' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: writes the php-upstream conf and removes default.conf" {
    grep -qF 'upstream php-upstream { server ${PHP_UPSTREAM_CONTAINER}:${PHP_UPSTREAM_PORT}; }' "${NGINX_DIR}/Dockerfile"
    grep -qF '/etc/nginx/conf.d/upstream.conf' "${NGINX_DIR}/Dockerfile"
    grep -qE 'rm -f /etc/nginx/conf\.d/default\.conf' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: creates the container-local sites-enabled directory" {
    grep -qE 'mkdir -p .*/etc/nginx/sites-enabled' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: strips CRs from startup.sh (Windows checkouts)" {
    grep -qF "sed -i 's/\\r//g' /opt/startup.sh" "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: CMD runs /opt/startup.sh with bash" {
    grep -qxF 'CMD ["/bin/bash", "/opt/startup.sh"]' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: exposes only 80 and 443" {
    grep -qxF 'EXPOSE 80 443' "${NGINX_DIR}/Dockerfile"
}

@test "nginx Dockerfile: has no {{TOKEN}} placeholders" {
    run grep -F '{{' "${NGINX_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

# ---- T03: nginx.conf -------------------------------------------------------

@test "nginx.conf: runs in the foreground (daemon off)" {
    grep -qE '^daemon off;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: access_log goes to /dev/stdout and error_log to /dev/stderr" {
    grep -qE '^\s+access_log /dev/stdout;' "${NGINX_DIR}/nginx.conf"
    grep -qE '^\s+error_log /dev/stderr;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: workers run as www-data (matches logrotate ownership and php-fpm)" {
    grep -qE '^user\s+www-data;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: pid file is /var/run/nginx.pid (what logrotate signals)" {
    grep -qE '^pid\s+/var/run/nginx\.pid;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: includes conf.d/*.conf (php-upstream) and the rendered sites-enabled/*.conf" {
    grep -qF 'include /etc/nginx/conf.d/*.conf;' "${NGINX_DIR}/nginx.conf"
    grep -qF 'include /etc/nginx/sites-enabled/*.conf;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: does not include the raw bind-mounted sites-available/ templates" {
    run grep -E '^\s*include /etc/nginx/sites-available' "${NGINX_DIR}/nginx.conf"
    [ "$status" -eq 1 ]
}

@test "nginx.conf: TLS is limited to TLSv1.2 and TLSv1.3" {
    grep -qE '^\s+ssl_protocols\s+TLSv1\.2 TLSv1\.3;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: deprecated TLSv1 / TLSv1.1 are not enabled" {
    run grep -E 'ssl_protocols.*TLSv1(\.1)?[ ;]' "${NGINX_DIR}/nginx.conf"
    [ "$status" -eq 1 ]
}

@test "nginx.conf: ssl_ciphers are ECDHE + AEAD only (no CBC, 3DES, DHE or RSA key exchange)" {
    local ciphers
    ciphers="$(grep -E '^\s+ssl_ciphers' "${NGINX_DIR}/nginx.conf")"
    [ -n "${ciphers}" ]
    [[ "${ciphers}" == *ECDHE-ECDSA-AES128-GCM-SHA256* ]]
    [[ "${ciphers}" == *ECDHE-RSA-CHACHA20-POLY1305* ]]
    run grep -E '^\s+ssl_ciphers.*(CBC|DES|[:'"'"' ]DHE-|[:'"'"' ]AES[0-9]+-)' "${NGINX_DIR}/nginx.conf"
    [ "$status" -eq 1 ]
    # every suite named must start with ECDHE-
    local suite
    for suite in $(echo "${ciphers}" | sed -E "s/^[^']*[ ]//; s/;//" | tr ':' ' '); do
        [[ "${suite}" == ECDHE-* ]]
    done
}

@test "nginx.conf: TLS session tickets off, shared session cache on" {
    grep -qE '^\s+ssl_session_tickets\s+off;' "${NGINX_DIR}/nginx.conf"
    grep -qE '^\s+ssl_session_cache\s+shared:SSL:' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: hides the nginx version and enables gzip" {
    grep -qE '^\s+server_tokens\s+off;' "${NGINX_DIR}/nginx.conf"
    grep -qE '^\s+gzip\s+on;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: leaves the upload size limit to PHP (client_max_body_size 0)" {
    grep -qE '^\s+client_max_body_size\s+0;' "${NGINX_DIR}/nginx.conf"
}

@test "nginx.conf: does not send HSTS (browsers cache it per host; harmful for dev domains)" {
    run grep -iE '^\s*add_header\s+Strict-Transport-Security' "${NGINX_DIR}/nginx.conf"
    [ "$status" -eq 1 ]
}

@test "nginx.conf: has no {{TOKEN}} placeholders" {
    run grep -F '{{' "${NGINX_DIR}/nginx.conf"
    [ "$status" -eq 1 ]
}
