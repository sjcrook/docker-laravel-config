#!/bin/bash
# Run this on your HOST (macOS/Linux/WSL) to generate browser-trusted certs via mkcert.
# Prerequisites: install mkcert (e.g. `brew install mkcert`) and run `mkcert -install` once.
#
# default.crt / default.key are written next to this script. They are bind-mounted into
# the nginx container at /etc/nginx/ssl/, and are trusted by your browser because the
# mkcert local CA is in your system trust store.
#
# Usage: ./generate-keys.sh <domain> [alias1] [alias2] ...
# Example: ./generate-keys.sh myapp.local www.myapp.local test.myapp.local

if [ -z "$1" ]; then
    echo "Usage: ./generate-keys.sh <domain> [alias1] [alias2] ..."
    echo "Example: ./generate-keys.sh myapp.local www.myapp.local"
    exit 1
fi

DOMAIN="$1"
shift
# All remaining arguments are treated as additional aliases

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MKCERT="$(command -v mkcert || command -v /opt/homebrew/bin/mkcert || true)"
if [ -z "$MKCERT" ]; then
    echo "ERROR: mkcert not found. Install it (e.g. 'brew install mkcert') and run 'mkcert -install' once."
    exit 1
fi

"$MKCERT" -cert-file "${SCRIPT_DIR}/default.crt" \
          -key-file "${SCRIPT_DIR}/default.key" \
          "$DOMAIN" "$@" localhost 127.0.0.1 ::1 || exit $?

# The nginx container's user must be able to read the key from the bind mount.
chmod 644 "${SCRIPT_DIR}/default.key"

NAMES="$DOMAIN"
[ "$#" -gt 0 ] && NAMES="${NAMES}, $*"
echo "Done. Certs generated for: ${NAMES}, localhost, 127.0.0.1, ::1"
