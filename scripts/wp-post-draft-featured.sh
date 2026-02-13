#!/bin/bash
# Author: cmondary - https://github.com/mondary
set -euo pipefail

# Crée un brouillon WordPress avec une featured image
# Usage: ./wp-post-draft-featured.sh "Titre" "Contenu" "URL_IMAGE"

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 \"Titre\" \"Contenu\" \"URL_IMAGE\""
  echo ""
  echo "Exemple:"
  echo "  $0 \"Mon article\" \"Le contenu de mon article\" \"https://example.com/image.jpg\""
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/secrets.sh"
source "$SCRIPT_DIR/rest-featured-media.sh"

TITLE="$1"
CONTENT="$2"
IMAGE_URL="$3"

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

echo "Upload de l'image..."
FEATURED_MEDIA_ID=""
FEATURED_MEDIA_ID="$(upload_featured_media_from_url "$IMAGE_URL" || true)"

if [ -z "$FEATURED_MEDIA_ID" ]; then
  echo "Erreur: impossible d'uploader l'image"
  exit 1
fi

echo "Image uploadée (ID: $FEATURED_MEDIA_ID)"
echo "Création du brouillon..."

TITLE_ESCAPED="$(json_escape "$TITLE")"
CONTENT_ESCAPED="$(json_escape "$CONTENT")"

JSON_PAYLOAD="{\"title\":\"$TITLE_ESCAPED\",\"content\":\"$CONTENT_ESCAPED\",\"status\":\"draft\",\"featured_media\":$FEATURED_MEDIA_ID}"

RESPONSE=$(curl -sS -X POST \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -u "$WP_USERNAME:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$WP_SITE_URL/wp-json/wp/v2/posts")

if echo "$RESPONSE" | grep -q '"id"'; then
  POST_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
  echo ""
  echo "Brouillon créé avec succès!"
  echo "ID: $POST_ID"
  echo "URL: $WP_SITE_URL/?p=$POST_ID"
  echo "Edit: $WP_SITE_URL/wp-admin/post.php?post=$POST_ID&action=edit"
else
  echo "Erreur lors de la création du brouillon:"
  echo "$RESPONSE"
  exit 1
fi
