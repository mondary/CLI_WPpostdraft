#!/bin/bash
set -euo pipefail

# Create an app-style WordPress post through REST API from a data file.
# Usage: ./wp-post-rest-app-from-file.sh [path/to/article_data.txt]
# Data file format (6 lines):
# 1 APP_NAME
# 2 SHORT_DESCRIPTION
# 3 URL
# 4 IMAGE_URL
# 5 DETAILS_HTML_OR_TEXT
# 6 STATUS (optional, defaults to draft when empty)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/secrets.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/rest-featured-media.sh"

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

DATA_FILE="${1:-$SCRIPT_DIR/article_data.txt}"
if [ ! -f "$DATA_FILE" ]; then
  echo "Missing data file: $DATA_FILE"
  echo "Tip: copy $SCRIPT_DIR/article_data.example.txt to $SCRIPT_DIR/article_data.txt"
  exit 1
fi

APP_NAME=$(sed -n '1p' "$DATA_FILE")
DESCRIPTION=$(sed -n '2p' "$DATA_FILE")
URL=$(sed -n '3p' "$DATA_FILE")
IMAGE=$(sed -n '4p' "$DATA_FILE")
DETAILS=$(sed -n '5p' "$DATA_FILE")
STATUS_RAW=$(sed -n '6p' "$DATA_FILE")
STATUS="${STATUS_RAW:-draft}"
FEATURED_MEDIA_ID=""
FEATURED_URL_FALLBACK=false

if [ -z "$APP_NAME" ] || [ -z "$DESCRIPTION" ] || [ -z "$URL" ] || [ -z "$DETAILS" ]; then
  echo "Data file is incomplete. Required lines: 1,2,3,5"
  exit 1
fi
validate_post_status "$STATUS"
if [ -n "$IMAGE" ]; then
  FEATURED_MEDIA_ID="$(upload_featured_media_from_url "$IMAGE" || true)"
  if [ -z "$FEATURED_MEDIA_ID" ]; then
    FEATURED_URL_FALLBACK=true
  fi
fi

TITLE="$APP_NAME : $DESCRIPTION"
CONTENT="<p>$URL</p><p>📌 $APP_NAME est une application $DESCRIPTION.</p><p><img src=\"$IMAGE\" alt=\"$APP_NAME\" style=\"max-width: 100%; height: auto;\"/></p><p><strong>Avantages principaux :</strong></p>$DETAILS"

TITLE_ESCAPED="$(json_escape "$TITLE")"
CONTENT_ESCAPED="$(json_escape "$CONTENT")"
JSON_PAYLOAD="{\"title\":{\"raw\":\"$TITLE_ESCAPED\"},\"content\":{\"raw\":\"$CONTENT_ESCAPED\"},\"status\":\"$STATUS\"}"
if [ -n "$FEATURED_MEDIA_ID" ]; then
  JSON_PAYLOAD="{\"title\":{\"raw\":\"$TITLE_ESCAPED\"},\"content\":{\"raw\":\"$CONTENT_ESCAPED\"},\"status\":\"$STATUS\",\"featured_media\":$FEATURED_MEDIA_ID}"
fi

RESPONSE=$(curl -sS -X POST \
  -H "User-Agent: WP-CLI-OLD" \
  -u "$WP_USERNAME:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$WP_SITE_URL/wp-json/wp/v2/posts")

if echo "$RESPONSE" | grep -q '"id"'; then
  POST_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
  if [ "$FEATURED_URL_FALLBACK" = true ]; then
    if set_featured_image_url_via_xmlrpc "$POST_ID" "$IMAGE"; then
      echo "Featured fallback set via XML-RPC URL meta"
    else
      echo "Featured fallback failed (XML-RPC URL meta)"
    fi
  fi
  echo "Post created"
  echo "ID: $POST_ID"
  echo "Status: $STATUS"
  echo "URL: $WP_SITE_URL/?p=$POST_ID"
else
  echo "Post creation failed"
  echo "$RESPONSE"
  exit 1
fi
