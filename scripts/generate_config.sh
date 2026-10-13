#!/usr/bin/env bash
# Builds RecoveryiOS/Resources/Configuration.plist from .env (local) or CI environment variables.
# Missing values are written empty; the app then falls back to its offline mock providers.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$ROOT/.env" ]; then set -a; . "$ROOT/.env"; set +a; fi
OUT="$ROOT/RecoveryiOS/Resources/Configuration.plist"
KEYS=(OPENAI_API_KEY OPENAI_MODEL ANTHROPIC_API_KEY ANTHROPIC_MODEL
      MEETING_FEED_AA MEETING_FEED_NA MEETING_FEED_HA MEETING_FEED_SMART MEETING_FEED_ALANON)
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  echo '<plist version="1.0">'
  echo '<dict>'
  for key in "${KEYS[@]}"; do
    value="${!key:-}"
    value=$(printf '%s' "$value" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
    printf '\t<key>%s</key>\n\t<string>%s</string>\n' "$key" "$value"
  done
  echo '</dict>'
  echo '</plist>'
} > "$OUT"
echo "Wrote $OUT"
