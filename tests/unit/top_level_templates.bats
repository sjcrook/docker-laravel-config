#!/usr/bin/env bats
# T11, T12 — templates/docker-compose.yml and templates/snippets/node-service.yml (functional-spec §8.1)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    COMPOSE="${REPO_ROOT}/templates/docker-compose.yml"
    NODE="${REPO_ROOT}/templates/snippets/node-service.yml"
}

tokens_in() {
    grep -oE '\{\{[A-Z_]+\}\}' "$1" | sort -u
}

# ---- T11: docker-compose.yml -------------------------------------------------

@test "compose: uses exactly the five tokens" {
    [ "$(tokens_in "$COMPOSE")" = "$(printf '{{HOST_HTTP_PORT}}\n{{HOST_HTTPS_PORT}}\n{{HOST_PGADMIN_PORT}}\n{{HOST_SSH_PORT}}\n{{NODE_SERVICE_BLOCK}}')" ]
}

@test "compose: has pgadmin, postgres, nginx and php-fpm services" {
    for s in pgadmin postgres nginx php-fpm; do grep -qxF "    ${s}:" "$COMPOSE"; done
}

@test "compose: all four host ports are token-driven" {
    grep -qF '"{{HOST_PGADMIN_PORT}}:80"' "$COMPOSE"
    grep -qF '"{{HOST_HTTPS_PORT}}:443"' "$COMPOSE"
    grep -qF '"{{HOST_HTTP_PORT}}:80"' "$COMPOSE"
    grep -qF '"{{HOST_SSH_PORT}}:22"' "$COMPOSE"
}

@test "compose: {{NODE_SERVICE_BLOCK}} is alone on its line, immediately before top-level networks:" {
    run grep -nxF '{{NODE_SERVICE_BLOCK}}' "$COMPOSE"
    [ "$status" -eq 0 ]
    line="${output%%:*}"
    [ "$(sed -n "$((line + 1))p" "$COMPOSE")" = 'networks:' ]
}

@test "compose: nginx receives NGINX_SERVER_NAME and NGINX_SERVER_ALIAS" {
    grep -qF 'NGINX_SERVER_NAME: ${NGINX_SERVER_NAME}' "$COMPOSE"
    grep -qF 'NGINX_SERVER_ALIAS: ${NGINX_SERVER_ALIAS}' "$COMPOSE"
}

@test "compose: php-fpm has extra_hosts and XDEBUG_MODE / RUN_CRON / OPCACHE_ENABLE_CLI" {
    grep -qxF '            - "host.docker.internal:host-gateway"' "$COMPOSE"
    grep -qE '^\s+extra_hosts:$' "$COMPOSE"
    grep -qE '^\s+XDEBUG_MODE:' "$COMPOSE"
    grep -qE '^\s+RUN_CRON:' "$COMPOSE"
    grep -qE '^\s+OPCACHE_ENABLE_CLI:' "$COMPOSE"
}

@test "compose: no obsolete top-level version key and no hardcoded host ports" {
    run grep -E '^version:' "$COMPOSE"
    [ "$status" -eq 1 ]
    run grep -E '"[0-9]+:(22|80|443)"' "$COMPOSE"
    [ "$status" -eq 1 ]
}

@test "compose: renders to valid-looking YAML with the node block spliced in" {
    out="$(sed -e 's/{{HOST_HTTP_PORT}}/80/' -e 's/{{HOST_HTTPS_PORT}}/443/' -e 's/{{HOST_SSH_PORT}}/2222/' \
               -e 's/{{HOST_PGADMIN_PORT}}/8081/' -e "/^{{NODE_SERVICE_BLOCK}}\$/{r ${NODE}" -e 'd;}' "$COMPOSE")"
    [[ "$out" != *'{{'* ]]
    [[ "$out" == *$'    node:\n        image: node:20-alpine'* ]]
    ! grep -P '\t' <<<"$out"
}

# ---- T12: node-service.yml ---------------------------------------------------

@test "node snippet: node:20-alpine one-shot with empty entrypoint and command true" {
    grep -qxF '    node:' "$NODE"
    grep -qxF '        image: node:20-alpine' "$NODE"
    grep -qxF '        entrypoint: [""]' "$NODE"
    grep -qxF '        command: ["true"]' "$NODE"
}

@test "node snippet: uses compose env vars, the sail network, and no tokens" {
    grep -qF 'working_dir: ${APP_CODE_PATH_CONTAINER}' "$NODE"
    grep -qF '${APP_CODE_PATH_HOST}:${APP_CODE_PATH_CONTAINER}${APP_CODE_CONTAINER_FLAG}' "$NODE"
    grep -qxF '            - sail' "$NODE"
    [ -z "$(tokens_in "$NODE")" ]
}

@test "node snippet: does not end with a blank line (block sits directly above networks:)" {
    [ -n "$(tail -n1 "$NODE")" ]
}
