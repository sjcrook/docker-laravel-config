#!/usr/bin/env bash
# Notification stub called by external/ai-session-kit/scripts/check-handoff.sh as:
#   ./notify.sh "<subject>" "<message>"
# Replace the TODO below with a real notification (email/Slack/etc). Until implemented,
# this just logs so the Stop hook never fails.
set -uo pipefail

SUBJECT="${1:-Coding session blocked}"
MESSAGE="${2:-}"
LOG_FILE="docs/.handoff-notifications.log"

# TODO: send $SUBJECT / $MESSAGE somewhere real, e.g.:
#   set -a; [ -f .env ] && source .env; set +a
#   ./send-email-to-mailgun.sh "$SUBJECT" "$MESSAGE"

echo "$(date -u +%FT%TZ) notify.sh stub called: $SUBJECT" >>"$LOG_FILE"
exit 0
