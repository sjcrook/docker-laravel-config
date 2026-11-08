#!/usr/bin/env bash
# Notification stub called by external/ai-session-kit/scripts/check-handoff.sh as:
#   ./notify.sh "<subject>" "<message>"
# Replace the TODO below with a real notification (email/Slack/etc). Until implemented,
# this just logs so the Stop hook never fails.
set -uo pipefail

SUBJECT="${1:-Coding session blocked}"
MESSAGE="${2:-}"
LOG_FILE=".ai-session/handoff-notifications.log"

if ! mkdir -p .ai-session; then
  echo "Cannot create .ai-session runtime directory for notifications." >&2
  exit 1
fi

# TODO: send $SUBJECT / $MESSAGE somewhere real, e.g.:
#   # Only source .env if it is a trusted, shell-compatible file.
#   if [ -f .env ]; then set -a; . ./.env; set +a; fi
#   ./send-email-to-mailgun.sh "$SUBJECT" "$MESSAGE"

if ! echo "$(date -u +%FT%TZ) notify.sh stub called: $SUBJECT" >>"$LOG_FILE"; then
  echo "Cannot write notification log $LOG_FILE." >&2
  exit 1
fi
exit 0
