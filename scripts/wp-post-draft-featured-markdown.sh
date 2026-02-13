#!/bin/bash
# Author: cmondary - https://github.com/mondary
set -euo pipefail

# Crée un brouillon WordPress avec featured image et contenu Markdown
# Supporte: gras, italique, code, listes, liens, images, YouTube
#
# Usage: ./wp-post-draft-featured-markdown.sh "Titre" "Contenu Markdown" "URL_IMAGE_FEATURED"
# Ou:    ./wp-post-draft-featured-markdown.sh "Titre" -f fichier.md "URL_IMAGE_FEATURED"

show_help() {
  cat << 'EOF'
Usage: wp-post-draft-featured-markdown.sh "Titre" "Contenu" "URL_IMAGE_FEATURED"
   ou: wp-post-draft-featured-markdown.sh "Titre" -f fichier.md "URL_IMAGE_FEATURED"

Markdown supporté:
  # Titre               → titre h1
  ## Titre              → titre h2 (jusqu'à h6)
  **gras**              → texte en gras
  *italique*            → texte en italique
  `code inline`         → code inline
  ```code block```      → bloc de code
  - item                → liste à puces
  [texte](url)          → lien
  ![alt](url)           → image
  https://youtube.com/... ou https://youtu.be/... → embed YouTube

Exemple:
  ./wp-post-draft-featured-markdown.sh "Mon Article" "**Hello** world!" "https://example.com/image.jpg"
EOF
}

if [ "$#" -lt 3 ]; then
  show_help
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/secrets.sh"
source "$SCRIPT_DIR/rest-featured-media.sh"

TITLE="$1"
shift

# Gestion du contenu: soit direct, soit depuis fichier
if [ "$1" = "-f" ]; then
  if [ ! -f "$2" ]; then
    echo "Erreur: fichier non trouvé: $2"
    exit 1
  fi
  CONTENT="$(cat "$2")"
  shift 2
else
  CONTENT="$1"
  shift
fi

IMAGE_URL="$1"

# Conversion Markdown → HTML
markdown_to_html() {
  local text="$1"

  # Blocs de code (``` ... ```) - doit être fait en premier
  local code_blocks=()
  local i=0
  while [[ "$text" =~ \`\`\`([^\`]*)\`\`\` ]]; do
    code_blocks+=("${BASH_REMATCH[1]}")
    text="${text/\`\`\`${BASH_REMATCH[1]}\`\`\`/___CODEBLOCK_${i}___}"
    ((i++))
  done

  # Code inline `code`
  while [[ "$text" =~ \`([^\`]+)\` ]]; do
    text="${text/\`${BASH_REMATCH[1]}\`/<code>${BASH_REMATCH[1]}</code>}"
  done

  # Gras **text**
  while [[ "$text" =~ \*\*([^*]+)\*\* ]]; do
    text="${text/\*\*${BASH_REMATCH[1]}\*\*/<strong>${BASH_REMATCH[1]}</strong>}"
  done

  # Italique *text*
  while [[ "$text" =~ \*([^*]+)\* ]]; do
    text="${text/\*${BASH_REMATCH[1]}\*/<em>${BASH_REMATCH[1]}</em>}"
  done

  # Images ![alt](url)
  while [[ "$text" =~ \!\[([^\]]*)\]\(([^\)]+)\) ]]; do
    local alt="${BASH_REMATCH[1]}"
    local url="${BASH_REMATCH[2]}"
    text="${text/\!\[${alt}\]\(${url}\)/<img src=\"${url}\" alt=\"${alt}\" style=\"max-width: 100%; height: auto;\"\/>}"
  done

  # Liens [text](url)
  while [[ "$text" =~ \[([^\]]+)\]\(([^\)]+)\) ]]; do
    local link_text="${BASH_REMATCH[1]}"
    local url="${BASH_REMATCH[2]}"
    text="${text/\[${link_text}\]\(${url}\)/<a href=\"${url}\">${link_text}</a>}"
  done

  # YouTube URLs → iframe embed
  while [[ "$text" =~ (https?://(www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]+)) ]]; do
    local full_url="${BASH_REMATCH[1]}"
    local video_id="${BASH_REMATCH[3]}"
    local embed="<div class=\"video-container\"><iframe width=\"560\" height=\"315\" src=\"https://www.youtube.com/embed/${video_id}\" frameborder=\"0\" allowfullscreen></iframe></div>"
    text="${text//${full_url}/${embed}}"
  done
  while [[ "$text" =~ (https?://youtu\.be/([a-zA-Z0-9_-]+)) ]]; do
    local full_url="${BASH_REMATCH[1]}"
    local video_id="${BASH_REMATCH[2]}"
    local embed="<div class=\"video-container\"><iframe width=\"560\" height=\"315\" src=\"https://www.youtube.com/embed/${video_id}\" frameborder=\"0\" allowfullscreen></iframe></div>"
    text="${text//${full_url}/${embed}}"
  done

  # Listes à puces et titres (ligne par ligne)
  local in_list=false
  local result=""
  local IFS=$'\n'
  for line in $text; do
    # Titres ###### à #
    if [[ "$line" =~ ^######[[:space:]]+(.*) ]]; then
      if [ "$in_list" = true ]; then result+="</ul>"; in_list=false; fi
      result+="<h6>${BASH_REMATCH[1]}</h6>"
    elif [[ "$line" =~ ^#####[[:space:]]+(.*) ]]; then
      if [ "$in_list" = true ]; then result+="</ul>"; in_list=false; fi
      result+="<h5>${BASH_REMATCH[1]}</h5>"
    elif [[ "$line" =~ ^####[[:space:]]+(.*) ]]; then
      if [ "$in_list" = true ]; then result+="</ul>"; in_list=false; fi
      result+="<h4>${BASH_REMATCH[1]}</h4>"
    elif [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
      if [ "$in_list" = true ]; then result+="</ul>"; in_list=false; fi
      result+="<h3>${BASH_REMATCH[1]}</h3>"
    elif [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
      if [ "$in_list" = true ]; then result+="</ul>"; in_list=false; fi
      result+="<h2>${BASH_REMATCH[1]}</h2>"
    elif [[ "$line" =~ ^#[[:space:]]+(.*) ]]; then
      if [ "$in_list" = true ]; then result+="</ul>"; in_list=false; fi
      result+="<h1>${BASH_REMATCH[1]}</h1>"
    # Listes à puces
    elif [[ "$line" =~ ^[[:space:]]*[-\*][[:space:]]+(.*) ]]; then
      if [ "$in_list" = false ]; then
        result+="<ul>"
        in_list=true
      fi
      result+="<li>${BASH_REMATCH[1]}</li>"
    else
      if [ "$in_list" = true ]; then
        result+="</ul>"
        in_list=false
      fi
      if [ -n "$line" ]; then
        result+="<p>$line</p>"
      fi
    fi
  done
  if [ "$in_list" = true ]; then
    result+="</ul>"
  fi
  text="$result"

  # Restaurer les blocs de code
  for ((j=0; j<${#code_blocks[@]}; j++)); do
    local escaped_code="${code_blocks[$j]}"
    escaped_code="${escaped_code//</&lt;}"
    escaped_code="${escaped_code//>/&gt;}"
    text="${text//___CODEBLOCK_${j}___/<pre><code>${escaped_code}</code></pre>}"
  done

  printf '%s' "$text"
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

echo "Conversion Markdown → HTML..."
HTML_CONTENT="$(markdown_to_html "$CONTENT")"

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
CONTENT_ESCAPED="$(json_escape "$HTML_CONTENT")"

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
