#!/usr/bin/env bats
# T08, T09 — templates/docker/php-fpm/Dockerfile and laravel.ini (functional-spec §8.6, §8.7)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    FPM_DIR="${REPO_ROOT}/templates/docker/php-fpm"
}

# Distinct {{TOKEN}} names used in a file, one per line.
tokens_in() {
    grep -oE '\{\{[A-Z_]+\}\}' "$1" | sort -u
}

# ---- T08: Dockerfile ---------------------------------------------------------

@test "php-fpm Dockerfile: base image is php:{{PHP_VERSION}}-fpm" {
    grep -qxF 'FROM php:{{PHP_VERSION}}-fpm' "${FPM_DIR}/Dockerfile"
}

@test "php-fpm Dockerfile: uses exactly the three tokens PHP_VERSION, PG_CLIENT_VERSION, NODE_APT_BLOCK" {
    [ "$(tokens_in "${FPM_DIR}/Dockerfile")" = "$(printf '{{NODE_APT_BLOCK}}\n{{PG_CLIENT_VERSION}}\n{{PHP_VERSION}}')" ]
}

@test "php-fpm Dockerfile: installs postgresql-client-{{PG_CLIENT_VERSION}}" {
    grep -qF 'postgresql-client-{{PG_CLIENT_VERSION}}' "${FPM_DIR}/Dockerfile"
}

@test "php-fpm Dockerfile: composer comes from the official image via COPY --from" {
    grep -qF 'COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer' "${FPM_DIR}/Dockerfile"
    run grep -E 'getcomposer\.org|composer\.phar' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: ngrok apt repo uses bookworm, not buster" {
    grep -qE 'ngrok-agent\.s3\.amazonaws\.com bookworm main' "${FPM_DIR}/Dockerfile"
    run grep -F 'buster' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: PGDG suite is derived from the base image, not hardcoded" {
    grep -qF 'VERSION_CODENAME' "${FPM_DIR}/Dockerfile"
    run grep -E 'bookworm-pgdg|trixie-pgdg' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: does not graft hardcoded Debian suites onto the base image sources" {
    run grep -F 'debian.sources' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: pkg-config is in the apt package list" {
    grep -qE '^\s+pkg-config( \\)?$' "${FPM_DIR}/Dockerfile"
}

@test "php-fpm Dockerfile: group 1 extensions are pdo_pgsql pgsql bcmath gmp sockets pcntl" {
    grep -qxF 'RUN docker-php-ext-install pdo_pgsql pgsql bcmath gmp sockets pcntl' "${FPM_DIR}/Dockerfile"
}

@test "php-fpm Dockerfile: intl and zip are each configured then installed" {
    grep -qxF 'RUN docker-php-ext-configure intl && docker-php-ext-install intl' "${FPM_DIR}/Dockerfile"
    grep -qxF 'RUN docker-php-ext-configure zip && docker-php-ext-install zip' "${FPM_DIR}/Dockerfile"
}

@test "php-fpm Dockerfile: opcache is not passed to docker-php-ext-install" {
    run grep -E 'docker-php-ext-install.*opcache' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: {{NODE_APT_BLOCK}} sits alone in its own paragraph" {
    run grep -nxF '{{NODE_APT_BLOCK}}' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 0 ]
    line="${output%%:*}"
    [ -z "$(sed -n "$((line - 1))p" "${FPM_DIR}/Dockerfile")" ]
    [ -z "$(sed -n "$((line + 1))p" "${FPM_DIR}/Dockerfile")" ]
}

@test "php-fpm Dockerfile: xdebug uses pecl config-set php_ini then pecl install, with no docker-php-ext-enable" {
    grep -qE 'pecl config-set php_ini /usr/local/etc/php/conf\.d/docker-php-ext-xdebug\.ini' "${FPM_DIR}/Dockerfile"
    grep -qF 'pecl install xdebug' "${FPM_DIR}/Dockerfile"
    run grep -F 'docker-php-ext-enable' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: xdebug stays inactive at build time (pecl's activation stub is removed)" {
    grep -qE 'rm -f /usr/local/etc/php/conf\.d/docker-php-ext-xdebug\.ini' "${FPM_DIR}/Dockerfile"
}

@test "php-fpm Dockerfile: copies laravel.ini and docker-entrypoint.sh, ends with ENTRYPOINT + CMD php-fpm" {
    grep -qE '^COPY (\./)?laravel\.ini /usr/local/etc/php/conf\.d/' "${FPM_DIR}/Dockerfile"
    grep -qE '^COPY (\./)?docker-entrypoint\.sh /usr/local/bin/' "${FPM_DIR}/Dockerfile"
    grep -qxF 'ENTRYPOINT ["docker-entrypoint.sh"]' "${FPM_DIR}/Dockerfile"
    [ "$(tail -n1 "${FPM_DIR}/Dockerfile")" = 'CMD ["php-fpm"]' ]
}

@test "php-fpm Dockerfile: sshd restrictions go in sshd_config.d, not the client ssh_config" {
    grep -qF '/etc/ssh/sshd_config.d/' "${FPM_DIR}/Dockerfile"
    run grep -E '/etc/ssh/ssh_config([^_]|$)' "${FPM_DIR}/Dockerfile"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: leaves no tokens once all three are substituted" {
    out="$(sed -e 's/{{PHP_VERSION}}/8.5/g' -e 's/{{PG_CLIENT_VERSION}}/18/g' -e '/^{{NODE_APT_BLOCK}}$/d' "${FPM_DIR}/Dockerfile")"
    [[ "$out" != *'{{'* ]]
    [[ "$out" == *'FROM php:8.5-fpm'* ]]
    [[ "$out" == *'postgresql-client-18'* ]]
}

# ---- T09: laravel.ini --------------------------------------------------------

@test "laravel.ini: uses exactly the four tokens MEMORY_LIMIT UPLOAD_MAX_FILESIZE POST_MAX_SIZE TIMEZONE" {
    [ "$(tokens_in "${FPM_DIR}/laravel.ini")" = "$(printf '{{MEMORY_LIMIT}}\n{{POST_MAX_SIZE}}\n{{TIMEZONE}}\n{{UPLOAD_MAX_FILESIZE}}')" ]
}

@test "laravel.ini: timezone and size limits are driven by tokens" {
    grep -qxF 'date.timezone={{TIMEZONE}}' "${FPM_DIR}/laravel.ini"
    grep -qxF 'memory_limit = {{MEMORY_LIMIT}}' "${FPM_DIR}/laravel.ini"
    grep -qxF 'upload_max_filesize = {{UPLOAD_MAX_FILESIZE}}' "${FPM_DIR}/laravel.ini"
    grep -qxF 'post_max_size = {{POST_MAX_SIZE}}' "${FPM_DIR}/laravel.ini"
}

@test "laravel.ini: errors are logged, not displayed" {
    grep -qxF 'display_errors=Off' "${FPM_DIR}/laravel.ini"
    grep -qxF 'log_errors=On' "${FPM_DIR}/laravel.ini"
}

@test "laravel.ini: opcache.enable=1 and opcache.enable_cli is never set (entrypoint injects it)" {
    grep -qxF 'opcache.enable=1' "${FPM_DIR}/laravel.ini"
    run grep -E '^opcache\.enable_cli' "${FPM_DIR}/laravel.ini"
    [ "$status" -eq 1 ]
    grep -qE '^; .*opcache\.enable_cli.*(docker-entrypoint|injected)' "${FPM_DIR}/laravel.ini"
}

@test "laravel.ini: JIT is tracing with a zero buffer, documenting production values and Xdebug" {
    grep -qxF 'opcache.jit=tracing' "${FPM_DIR}/laravel.ini"
    grep -qxF 'opcache.jit_buffer_size=0' "${FPM_DIR}/laravel.ini"
    grep -qE '^; .*128M' "${FPM_DIR}/laravel.ini"
    grep -qiE '^; .*xdebug' "${FPM_DIR}/laravel.ini"
}

@test "laravel.ini: uses only ';' comments (PHP 7+ rejects '#' comments in ini files)" {
    run grep -nE '^\s*#' "${FPM_DIR}/laravel.ini"
    [ "$status" -eq 1 ]
}

@test "laravel.ini: contains no php-fpm pool directives (they live in the pool override)" {
    run grep -E '^(pm(\.[a-z_]+)?|request_terminate_timeout)[[:space:]]*=' "${FPM_DIR}/laravel.ini"
    [ "$status" -eq 1 ]
}

# ---- php-fpm pool override (moved out of laravel.ini) ------------------------

@test "php-fpm-pool.conf: is an invariant [www] pool override with the four pool directives" {
    [ -f "${FPM_DIR}/php-fpm-pool.conf" ]
    [ -z "$(tokens_in "${FPM_DIR}/php-fpm-pool.conf")" ]
    grep -qxF '[www]' "${FPM_DIR}/php-fpm-pool.conf"
    grep -qxF 'pm = ondemand' "${FPM_DIR}/php-fpm-pool.conf"
    grep -qxF 'pm.max_children = 5' "${FPM_DIR}/php-fpm-pool.conf"
    grep -qxF 'pm.process_idle_timeout = 10s' "${FPM_DIR}/php-fpm-pool.conf"
    grep -qxF 'request_terminate_timeout = 60s' "${FPM_DIR}/php-fpm-pool.conf"
}

@test "php-fpm-pool.conf: uses only ';' comments" {
    run grep -nE '^\s*#' "${FPM_DIR}/php-fpm-pool.conf"
    [ "$status" -eq 1 ]
}

@test "php-fpm Dockerfile: installs the pool override as php-fpm.d/zz-laravel.conf (sorts after zz-docker.conf)" {
    grep -qE '^COPY (\./)?php-fpm-pool\.conf /usr/local/etc/php-fpm\.d/zz-laravel\.conf$' "${FPM_DIR}/Dockerfile"
}

# ---- T10: docker-entrypoint.sh -----------------------------------------------

@test "entrypoint: bash shebang, valid syntax, no tokens" {
    [ "$(head -n1 "${FPM_DIR}/docker-entrypoint.sh")" = '#!/bin/bash' ]
    bash -n "${FPM_DIR}/docker-entrypoint.sh"
    [ -z "$(tokens_in "${FPM_DIR}/docker-entrypoint.sh")" ]
}

@test "entrypoint: cron starts only when RUN_CRON is yes" {
    grep -qF 'if [ "yes" == "${RUN_CRON}" ]; then' "${FPM_DIR}/docker-entrypoint.sh"
    grep -qE '^\s+cron -f &$' "${FPM_DIR}/docker-entrypoint.sh"
}

@test "entrypoint: clears the xdebug log and enables xdebug only when XDEBUG_MODE is non-empty" {
    grep -qxF 'rm -f /var/log/xdebug.log' "${FPM_DIR}/docker-entrypoint.sh"
    grep -qF 'if [ ! -z "${XDEBUG_MODE}" ]; then' "${FPM_DIR}/docker-entrypoint.sh"
    grep -qF 'docker-php-ext-enable xdebug' "${FPM_DIR}/docker-entrypoint.sh"
    grep -qF 'xdebug.mode=$XDEBUG_MODE' "${FPM_DIR}/docker-entrypoint.sh"
}

@test "entrypoint: starts sshd in the background and ends with exec \"\$@\"" {
    grep -qxF '/usr/sbin/sshd -D &' "${FPM_DIR}/docker-entrypoint.sh"
    [ "$(tail -n1 "${FPM_DIR}/docker-entrypoint.sh")" = 'exec "$@"' ]
}

@test "entrypoint: injects opcache.enable_cli into laravel.ini, exactly once across restarts" {
    grep -qF 'opcache.enable_cli=$OPCACHE_ENABLE_CLI' "${FPM_DIR}/docker-entrypoint.sh"
    T="$(mktemp -d)"
    mkdir -p "${T}/conf.d" "${T}/bin"
    printf 'memory_limit = 256M\n' > "${T}/conf.d/laravel.ini"
    for c in sshd; do printf '#!/bin/sh\nexit 0\n' > "${T}/bin/$c"; chmod +x "${T}/bin/$c"; done
    sed -e "s#/usr/local/etc/php/conf.d#${T}/conf.d#g" -e "s#/usr/sbin/sshd#${T}/bin/sshd#" -e "s#/var/log/xdebug.log#${T}/x.log#g" \
        "${FPM_DIR}/docker-entrypoint.sh" > "${T}/entry.sh"
    OPCACHE_ENABLE_CLI=0 run bash "${T}/entry.sh" true
    [ "$status" -eq 0 ]
    OPCACHE_ENABLE_CLI=1 run bash "${T}/entry.sh" true
    [ "$status" -eq 0 ]
    [ "$(grep -c '^opcache.enable_cli=' "${T}/conf.d/laravel.ini")" -eq 1 ]
    grep -qxF 'opcache.enable_cli=1' "${T}/conf.d/laravel.ini"
    grep -qxF 'memory_limit = 256M' "${T}/conf.d/laravel.ini"
    rm -rf "$T"
}
