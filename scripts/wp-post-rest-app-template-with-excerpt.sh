#!/bin/bash
set -euo pipefail

# Create an app-style post through REST API with excerpt and social message metadata.
# Usage: ./wp-post-rest-app-template-with-excerpt.sh "App Name" "Short Description" "URL" "Image URL" "Details" [draft|publish|pending|private]

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 \"App Name\" \"Short Description\" \"URL\" \"Image URL\" \"Details\" [draft|publish|pending|private]"
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

APP_NAME="$1"
DESCRIPTION="$2"
URL="$3"
IMAGE_URL="$4"
DETAILS="$5"
STATUS="${6:-draft}"
validate_post_status "$STATUS"

TITLE="$APP_NAME : $DESCRIPTION"
CONTENT="<p>$URL</p><p>📌 $APP_NAME est une application $DESCRIPTION.</p><p><img src=\"$IMAGE_URL\" alt=\"$APP_NAME\" style=\"max-width: 100%; height: auto;\"/></p><p><strong>Avantages principaux :</strong></p>$DETAILS"
EXCERPT="📌 $APP_NAME est une application $DESCRIPTION."
SOCIAL_MSG="$EXCERPT"

TITLE_ESCAPED="$(json_escape "$TITLE")"
CONTENT_ESCAPED="$(json_escape "$CONTENT")"
EXCERPT_ESCAPED="$(json_escape "$EXCERPT")"
SOCIAL_ESCAPED="$(json_escape "$SOCIAL_MSG")"
JSON_PAYLOAD="{\"title\":{\"raw\":\"$TITLE_ESCAPED\"},\"content\":{\"raw\":\"$CONTENT_ESCAPED\"},\"excerpt\":{\"raw\":\"$EXCERPT_ESCAPED\"},\"status\":\"$STATUS\",\"meta\":{\"jetpack_publicize_message\":\"$SOCIAL_ESCAPED\"}}"

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
