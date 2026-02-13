#!/bin/bash
set -euo pipefail

# Create a WordPress post through REST API from explicit title/content arguments.
# Usage: ./wp-post-rest-title-content.sh "Title" "Content" [draft|publish|pending|private]

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 \"Title\" \"Content\" [draft|publish|pending|private]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/secrets.sh"

validate_post_status() {
  case "$1" in
    draft|publish|pending|private) return 0 ;;
    *)
      echo "Invalid status '$1'. Allowed: draft|publish|pending|private"
      return 1
      ;;
  esac
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

TITLE="$1"
CONTENT="$2"
STATUS="${3:-draft}"
validate_post_status "$STATUS"

TITLE_ESCAPED="$(json_escape "$TITLE")"
CONTENT_ESCAPED="$(json_escape "$CONTENT")"
JSON_PAYLOAD="{\"title\":{\"raw\":\"$TITLE_ESCAPED\"},\"content\":{\"raw\":\"$CONTENT_ESCAPED\"},\"status\":\"$STATUS\"}"

RESPONSE=$(curl -sS -X POST \
  -H "User-Agent: WP-CLI-OLD" \
  -u "$WP_USERNAME:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$WP_SITE_URL/wp-json/wp/v2/posts")

if echo "$RESPONSE" | grep -q '"id"'; then
  POST_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
  echo "Post created"
  echo "ID: $POST_ID"
  echo "Status: $STATUS"
  echo "URL: $WP_SITE_URL/?p=$POST_ID"
else
  echo "Post creation failed"
  echo "$RESPONSE"
  exit 1
fi
