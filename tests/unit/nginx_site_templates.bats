#!/usr/bin/env bats
# T04 (static), T05, T06 — startup.sh, sites/laravel.conf, logrotate/nginx
# Behavioural tests for startup.sh live in nginx_startup.bats.

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    NGINX_DIR="${REPO_ROOT}/templates/docker/nginx"
}

# ---- T04: startup.sh (static) ----------------------------------------------

@test "startup.sh: starts with #!/bin/bash and has valid syntax" {
    [ "$(head -n1 "${NGINX_DIR}/startup.sh")" = '#!/bin/bash' ]
    bash -n "${NGINX_DIR}/startup.sh"
}

@test "startup.sh: uses the corrected 4-hourly cron (0 */4 * * *), not 0 0 */4 * *" {
    grep -qF '0 */4 * * * nginx -s reload' "${NGINX_DIR}/startup.sh"
    run grep -F '0 0 */4 * *' "${NGINX_DIR}/startup.sh"
    [ "$status" -eq 1 ]
}

@test "startup.sh: suppresses the first-run 'no crontab' error with crontab -l 2>/dev/null" {
    grep -qF 'crontab -l 2>/dev/null' "${NGINX_DIR}/startup.sh"
}

@test "startup.sh: envsubst is limited to NGINX_SERVER_NAME and NGINX_SERVER_ALIAS" {
    grep -qF "envsubst '\${NGINX_SERVER_NAME} \${NGINX_SERVER_ALIAS}'" "${NGINX_DIR}/startup.sh"
}

@test "startup.sh: execs nginx so it is PID 1 and receives SIGTERM directly" {
    grep -qE '^exec nginx$' "${NGINX_DIR}/startup.sh"
}

@test "startup.sh: has no hardcoded project domains or {{TOKEN}} placeholders" {
    run grep -E 'ipresenttoyou|cryptotrends|Sheridan|Hara LLC' "${NGINX_DIR}/startup.sh"
    [ "$status" -eq 1 ]
    run grep -F '{{' "${NGINX_DIR}/startup.sh"
    [ "$status" -eq 1 ]
}

# ---- T05: sites/laravel.conf -----------------------------------------------

@test "laravel.conf: server_name uses literal \${NGINX_SERVER_NAME} \${NGINX_SERVER_ALIAS}" {
    grep -qF 'server_name ${NGINX_SERVER_NAME} ${NGINX_SERVER_ALIAS};' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: listens on HTTP 80 and HTTPS 443, IPv4 and IPv6" {
    grep -qE '^\s+listen 80;' "${NGINX_DIR}/sites/laravel.conf"
    grep -qE '^\s+listen \[::\]:80;' "${NGINX_DIR}/sites/laravel.conf"
    grep -qE '^\s+listen 443 ssl;' "${NGINX_DIR}/sites/laravel.conf"
    grep -qE '^\s+listen \[::\]:443 ssl;' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: HTTP/2 uses the http2 directive, not the deprecated listen parameter" {
    grep -qE '^\s+http2 on;' "${NGINX_DIR}/sites/laravel.conf"
    run grep -E 'listen .*http2' "${NGINX_DIR}/sites/laravel.conf"
    [ "$status" -eq 1 ]
}

@test "laravel.conf: uses certs at /etc/nginx/ssl/default.crt and default.key" {
    grep -qF 'ssl_certificate /etc/nginx/ssl/default.crt;' "${NGINX_DIR}/sites/laravel.conf"
    grep -qF 'ssl_certificate_key /etc/nginx/ssl/default.key;' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: serves from the Laravel public/ directory" {
    grep -qF 'root /var/www/laravel/current/public;' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: only the front controller (index.php) is passed to php-upstream" {
    grep -qF 'location ~ ^/index\.php(/|$) {' "${NGINX_DIR}/sites/laravel.conf"
    grep -qF 'fastcgi_pass php-upstream;' "${NGINX_DIR}/sites/laravel.conf"
    grep -qF 'fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: no catch-all PHP location that would execute arbitrary .php files" {
    run grep -F 'location ~ \.php$' "${NGINX_DIR}/sites/laravel.conf"
    [ "$status" -eq 1 ]
}

@test "laravel.conf: denies dotfiles except .well-known, hides X-Powered-By" {
    grep -qF 'location ~ /\.(?!well-known).* {' "${NGINX_DIR}/sites/laravel.conf"
    grep -qF 'fastcgi_hide_header X-Powered-By;' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: sends X-Frame-Options and X-Content-Type-Options" {
    grep -qF 'add_header X-Frame-Options "SAMEORIGIN";' "${NGINX_DIR}/sites/laravel.conf"
    grep -qF 'add_header X-Content-Type-Options "nosniff";' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: logs to /var/log/nginx/laravel_*.log" {
    grep -qF 'error_log /var/log/nginx/laravel_error.log;' "${NGINX_DIR}/sites/laravel.conf"
    grep -qF 'access_log /var/log/nginx/laravel_access.log;' "${NGINX_DIR}/sites/laravel.conf"
}

@test "laravel.conf: no hardcoded domains, no production Let's Encrypt webroot, no {{TOKEN}}" {
    run grep -E 'ipresenttoyou|cryptotrends|letsencrypt|acme-challenge' "${NGINX_DIR}/sites/laravel.conf"
    [ "$status" -eq 1 ]
    run grep -F '{{' "${NGINX_DIR}/sites/laravel.conf"
    [ "$status" -eq 1 ]
}

# ---- T06: logrotate/nginx --------------------------------------------------

@test "logrotate: rotates /var/log/nginx/*.log daily, keeping 32 rotations" {
    grep -qF '/var/log/nginx/*.log {' "${NGINX_DIR}/logrotate/nginx"
    grep -qE '^\s+daily$' "${NGINX_DIR}/logrotate/nginx"
    grep -qE '^\s+rotate 32$' "${NGINX_DIR}/logrotate/nginx"
}

@test "logrotate: compress and delaycompress" {
    grep -qE '^\s+compress$' "${NGINX_DIR}/logrotate/nginx"
    grep -qE '^\s+delaycompress$' "${NGINX_DIR}/logrotate/nginx"
}

@test "logrotate: postrotate sends USR1 to the pid in /var/run/nginx.pid, guarded" {
    grep -qE '^\s+postrotate$' "${NGINX_DIR}/logrotate/nginx"
    grep -qF 'if [ -f /var/run/nginx.pid ]; then' "${NGINX_DIR}/logrotate/nginx"
    grep -qF 'kill -USR1 "$(cat /var/run/nginx.pid)"' "${NGINX_DIR}/logrotate/nginx"
    grep -qE '^\s+endscript$' "${NGINX_DIR}/logrotate/nginx"
}

@test "logrotate: has no {{TOKEN}} placeholders" {
    run grep -F '{{' "${NGINX_DIR}/logrotate/nginx"
    [ "$status" -eq 1 ]
}
