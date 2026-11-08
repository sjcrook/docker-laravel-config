#!/usr/bin/env bats
# T14 — templates/env.docker (functional-spec §6)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    ENVT="${REPO_ROOT}/templates/env.docker"
}

@test "env.docker: exists" {
    [ -f "$ENVT" ]
}

@test "env.docker: uses exactly the four tokens" {
    [ "$(grep -oE '\{\{[A-Z_]+\}\}' "$ENVT" | sort -u)" = "$(printf '{{HOST_HTTPS_PORT}}\n{{HOST_HTTP_PORT}}\n{{NGINX_SERVER_ALIAS}}\n{{NGINX_SERVER_NAME}}' | sort -u)" ]
}

@test "env.docker: token-driven nginx variables" {
    grep -qxF 'NGINX_HOST_HTTP_PORT={{HOST_HTTP_PORT}}' "$ENVT"
    grep -qxF 'NGINX_HOST_HTTPS_PORT={{HOST_HTTPS_PORT}}' "$ENVT"
    grep -qxF 'NGINX_SERVER_NAME={{NGINX_SERVER_NAME}}' "$ENVT"
    grep -qxF 'NGINX_SERVER_ALIAS={{NGINX_SERVER_ALIAS}}' "$ENVT"
}

@test "env.docker: static docker variables" {
    for l in 'APP_CODE_PATH_HOST=./' 'APP_CODE_PATH_CONTAINER=/var/www/laravel/current' \
        'APP_CODE_CONTAINER_FLAG=:cached' 'NGINX_HOST_LOG_PATH=./docker/logs/nginx/' \
        'NGINX_SITES_PATH=./docker/nginx/sites/' 'NGINX_SSL_PATH=./docker/nginx/ssl/' \
        'PHP_FPM_HOST_LOG_PATH=./docker/logs/php-fpm/'; do
        grep -qxF "$l" "$ENVT"
    done
}

@test "env.docker: starts with DOCKER header" {
    [ "$(head -n1 "$ENVT")" = '#### DOCKER ################################################################' ]
}

@test "env.docker: NOTE reminder lists DB and PGADMIN vars" {
    grep -qF 'NOTE: The following variables are required in your .env but are outside the scope of' "$ENVT"
    for l in '  DB_CONNECTION=pgsql' '  DB_HOST=postgres' '  DB_PORT=5432' '  DB_DATABASE=<your_database_name>' \
        '  DB_USERNAME=<your_db_username>' '  DB_PASSWORD=<your_db_password>' \
        '  PGADMIN_DEFAULT_EMAIL=<your_pgadmin_email>' '  PGADMIN_DEFAULT_PASSWORD=<your_pgadmin_password>'; do
        grep -qxF "$l" "$ENVT"
    done
}
