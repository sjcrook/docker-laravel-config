#!/bin/bash
set -eu

# Container entrypoint for the nginx service (invariant — no project-specific values).
# NGINX_SERVER_NAME / NGINX_SERVER_ALIAS come from the container environment
# (set in docker-compose.yml, sourced from the project's .env).

# NGINX_ETC_DIR is overridable only so this script can be exercised outside a container.
NGINX_ETC_DIR="${NGINX_ETC_DIR:-/etc/nginx}"
SSL_DIR="${NGINX_ETC_DIR}/ssl"
SITES_AVAILABLE="${NGINX_ETC_DIR}/sites-available"   # bind-mounted from the host (templates)
SITES_ENABLED="${NGINX_ETC_DIR}/sites-enabled"       # container-local (rendered output)

: "${NGINX_SERVER_NAME:?NGINX_SERVER_NAME must be set (see .env / docker-compose.yml)}"
DOMAIN="${NGINX_SERVER_NAME}"
ALIAS="${NGINX_SERVER_ALIAS:-}"   # space-separated; may be empty

if [ ! -f "${SSL_DIR}/default.crt" ] || [ ! -f "${SSL_DIR}/default.key" ]; then
    echo "WARNING: No cert/key found in ${SSL_DIR}"
    echo "Generating self-signed fallback cert. This will NOT work with HSTS enabled."
    echo "For browser-trusted certs, run on your HOST: docker/nginx/ssl/generate-keys.sh <domain> [alias...]"
    echo ""

    # Subject alternative names: domain + each alias (empty entries are skipped) + loopback.
    san="DNS:${DOMAIN}"
    # shellcheck disable=SC2086  # intentional word-splitting of the space-separated alias list
    for name in ${ALIAS}; do
        san="${san},DNS:${name}"
    done
    san="${san},DNS:localhost,IP:127.0.0.1,IP:::1"

    # Fallback: self-signed cert (browsers will block if HSTS is cached)
    openssl req -x509 -nodes -days 365 \
      -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
      -keyout "${SSL_DIR}/default.key" \
      -out "${SSL_DIR}/default.crt" \
      -subj "/CN=${DOMAIN}" \
      -addext "subjectAltName = ${san}"

    # World-readable so the host user can read it from the bind mount (dev-only key).
    chmod 644 "${SSL_DIR}/default.key"
fi

# Render NGINX_SERVER_NAME / NGINX_SERVER_ALIAS into the site configs. Output goes to a
# container-local directory: rendering in place would overwrite the bind-mounted host file,
# permanently replacing the placeholders with literal domains.
mkdir -p "${SITES_ENABLED}"
rm -f "${SITES_ENABLED}"/*.conf
for conf in "${SITES_AVAILABLE}"/*.conf; do
    [ -e "${conf}" ] || continue
    # shellcheck disable=SC2016  # single quotes intentional: envsubst takes a literal variable list
    envsubst '${NGINX_SERVER_NAME} ${NGINX_SERVER_ALIAS}' < "${conf}" > "${SITES_ENABLED}/$(basename "${conf}")"
done

# Reload nginx every 4 hours (refreshes SSL cert handles and clears stale connections).
# Drop any previous entry first so container restarts don't accumulate duplicates.
(crontab -l 2>/dev/null | grep -vF 'nginx -s reload' || true; echo "0 */4 * * * nginx -s reload") | crontab -

# Start crond in background
crond -l 2 -b

# Fail fast with a readable error if the rendered config is invalid
nginx -t

# exec so nginx is PID 1 and receives SIGTERM/SIGQUIT directly (fast `docker compose down`)
echo "NGINX starting; it will reload every 4 hours."
exec nginx
