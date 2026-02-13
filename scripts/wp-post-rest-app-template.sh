#!/bin/bash
# Author: cmondary - https://github.com/mondary
set -euo pipefail

# Create an app-style WordPress post through REST API from explicit app arguments.
# Usage: ./wp-post-rest-app-template.sh "App Name" "Short Description" "URL" "Details" [image_url] [draft|publish|pending|private]

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 \"App Name\" \"Short Description\" \"URL\" \"Details\" [image_url] [draft|publish|pending|private]"
  exit 1
fi

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

APP_NAME="$1"
DESCRIPTION="$2"
URL="$3"
DETAILS="$4"
IMAGE_URL="${5:-}"
STATUS="${6:-draft}"
validate_post_status "$STATUS"
FEATURED_MEDIA_ID=""
FEATURED_URL_FALLBACK=false

if [ -n "$IMAGE_URL" ]; then
  FEATURED_MEDIA_ID="$(upload_featured_media_from_url "$IMAGE_URL" || true)"
  if [ -z "$FEATURED_MEDIA_ID" ]; then
    FEATURED_URL_FALLBACK=true
  fi
fi

TITLE="$APP_NAME : $DESCRIPTION"
if [ -n "$IMAGE_URL" ]; then
  FORMATTED_CONTENT="<p>$URL</p><p><img src='$IMAGE_URL' alt='$APP_NAME' style='max-width: 100%; height: auto;'/></p><p>📌 $APP_NAME est $DETAILS</p>"
else
  FORMATTED_CONTENT="<p>$URL</p><p>📌 $APP_NAME est $DETAILS</p>"
fi

TITLE_ESCAPED="$(json_escape "$TITLE")"
CONTENT_ESCAPED="$(json_escape "$FORMATTED_CONTENT")"
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
    if set_featured_image_url_via_xmlrpc "$POST_ID" "$IMAGE_URL"; then
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
