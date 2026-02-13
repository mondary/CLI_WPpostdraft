#!/bin/bash
# Author: cmondary - https://github.com/mondary
set -euo pipefail

# Script complet pour créer un post WordPress programmé avec:
# - Featured image
# - Contenu Markdown
# - Slug personnalisé
# - Excerpt
# - Jetpack Social (message + image pour réseaux sociaux)
# - Catégories (par nom)
# - Programmation intelligente au prochain jour libre

show_help() {
  cat << 'EOF'
Usage: wp-post-draft-full.sh [OPTIONS]

Options requises:
  -t, --title "Titre"           Titre du post
  -c, --content "Markdown"      Contenu en Markdown
  -i, --image "URL"             URL de l'image featured

Options facultatives:
  -f, --file fichier.md         Lire le contenu depuis un fichier (remplace -c)
  -s, --slug "mon-slug"         Slug personnalisé pour l'URL
  -e, --excerpt "Extrait"       Extrait/résumé du post
  -j, --social "Message"        Message Jetpack Social (max 300 car.)
  -C, --categories "Cat1,Cat2"  Catégories (noms séparés par virgule)
  --list-categories             Lister les catégories disponibles et quitter
  -h, --help                    Afficher cette aide

Options de date:
  --draft                       Créer un brouillon simple (sans date)
  -d, --date "YYYY-MM-DD"       Définir une date spécifique
  --hour "HH:MM"                Heure de publication (défaut: 14:00)
  (par défaut)                  Trouve le prochain jour sans article

Markdown supporté:
  # à ######     Titres h1 à h6
  **gras**       Texte en gras
  *italique*     Texte en italique
  `code`         Code inline
  ```code```     Bloc de code
  - item         Liste à puces
  [txt](url)     Lien
  ![alt](url)    Image
  URL YouTube    Embed vidéo

Exemples:
  # Brouillon avec date au prochain jour libre (défaut)
  ./wp-post-draft-full.sh -t "Mon Article" -c "Contenu" -i "https://img.jpg"

  # Brouillon simple sans date
  ./wp-post-draft-full.sh -t "Mon Article" -c "Contenu" -i "https://img.jpg" --draft

  # Brouillon avec date spécifique
  ./wp-post-draft-full.sh -t "Mon Article" -c "Contenu" -i "https://img.jpg" -d "2026-03-15"
EOF
}

# Initialisation des variables
TITLE=""
CONTENT=""
IMAGE_URL=""
SLUG=""
EXCERPT=""
SOCIAL_MSG=""
CATEGORIES=""
LIST_CATEGORIES=false
DRAFT_MODE=false
SCHEDULE_DATE=""
SCHEDULE_HOUR="14:00"

# Parse des arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--title) TITLE="$2"; shift 2 ;;
    -c|--content) CONTENT="$2"; shift 2 ;;
    -i|--image) IMAGE_URL="$2"; shift 2 ;;
    -f|--file)
      if [ ! -f "$2" ]; then
        echo "Erreur: fichier non trouvé: $2" >&2
        exit 1
      fi
      CONTENT="$(cat "$2")"
      shift 2
      ;;
    -s|--slug) SLUG="$2"; shift 2 ;;
    -e|--excerpt) EXCERPT="$2"; shift 2 ;;
    -j|--social) SOCIAL_MSG="$2"; shift 2 ;;
    -C|--categories) CATEGORIES="$2"; shift 2 ;;
    --list-categories) LIST_CATEGORIES=true; shift ;;
    --draft) DRAFT_MODE=true; shift ;;
    -d|--date) SCHEDULE_DATE="$2"; shift 2 ;;
    --hour) SCHEDULE_HOUR="$2"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Option inconnue: $1" >&2; show_help; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================================
# Chargement des credentials WordPress
# ============================================================================
CREDENTIALS_FILE="${WP_CLI_OLD_CONFIG_FILE:-$SCRIPT_DIR/../secrets/wp-credentials}"

if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "Fichier credentials manquant: $CREDENTIALS_FILE" >&2
  echo "Format attendu (3 lignes): site_url, username, app_password" >&2
  exit 1
fi

WP_SITE_URL="$(sed -n '1p' "$CREDENTIALS_FILE" | tr -d '\r')"
WP_USERNAME="$(sed -n '2p' "$CREDENTIALS_FILE" | tr -d '\r')"
WP_APP_PASSWORD="$(sed -n '3p' "$CREDENTIALS_FILE" | tr -d '\r')"

if [ -z "$WP_SITE_URL" ] || [ -z "$WP_USERNAME" ] || [ -z "$WP_APP_PASSWORD" ]; then
  echo "Fichier credentials invalide: $CREDENTIALS_FILE" >&2
  echo "Format attendu (3 lignes): site_url, username, app_password" >&2
  exit 1
fi

# ============================================================================
# Fonction d'upload d'image vers la médiathèque WordPress
# ============================================================================
normalize_image_to_16_9() {
  local image_path="$1"
  local width height scale new_w new_h

  if ! command -v sips >/dev/null 2>&1; then
    echo "Erreur: sips est requis pour forcer le format featured 16:9" >&2
    return 1
  fi

  width="$(sips -g pixelWidth "$image_path" 2>/dev/null | awk '/pixelWidth:/{print $2}' | tail -n1)"
  height="$(sips -g pixelHeight "$image_path" 2>/dev/null | awk '/pixelHeight:/{print $2}' | tail -n1)"

  if [ -z "$width" ] || [ -z "$height" ]; then
    echo "Erreur: impossible de lire les dimensions de l'image" >&2
    return 1
  fi

  # Assure une base suffisante pour recadrer proprement en 1600x900
  if [ "$width" -lt 1600 ] || [ "$height" -lt 900 ]; then
    scale="$(awk -v w="$width" -v h="$height" 'BEGIN{
      s1=1600.0/w; s2=900.0/h; print (s1>s2?s1:s2)
    }')"
    new_w="$(awk -v w="$width" -v s="$scale" 'BEGIN{printf "%d", (w*s)+0.5}')"
    new_h="$(awk -v h="$height" -v s="$scale" 'BEGIN{printf "%d", (h*s)+0.5}')"
    sips -z "$new_h" "$new_w" "$image_path" >/dev/null 2>&1 || return 1
  fi

  # Recadrage systématique en paysage 16:9
  sips --cropToHeightWidth 900 1600 "$image_path" >/dev/null 2>&1 || return 1
  return 0
}

upload_featured_media_from_url() {
  local image_url="$1"
  if [ -z "$image_url" ]; then
    echo "URL image manquante" >&2
    return 1
  fi
  if [[ ! "$image_url" =~ ^https?:// ]]; then
    echo "Seules les URLs HTTP(S) sont supportées: $image_url" >&2
    return 1
  fi

  local base_url filename stem ext tmp_file mime_type response media_id
  base_url="${WP_SITE_URL%/}"
  filename="$(basename "${image_url%%\?*}")"
  if [ -z "$filename" ] || [ "$filename" = "/" ]; then
    filename="featured-$(date +%s).jpg"
  fi
  stem="${filename%.*}"
  ext="${filename##*.}"
  if [ "$stem" = "$filename" ]; then
    ext="jpg"
    filename="${filename}.jpg"
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/wprestimg.XXXXXX.${ext}")"

  if ! curl -fLsS "$image_url" -o "$tmp_file"; then
    echo "Échec du téléchargement: $image_url" >&2
    rm -f "$tmp_file"
    return 1
  fi

  if ! normalize_image_to_16_9 "$tmp_file"; then
    echo "Erreur: impossible de convertir l'image en featured paysage 16:9" >&2
    rm -f "$tmp_file"
    return 1
  fi

  if command -v file >/dev/null 2>&1; then
    mime_type="$(file -b --mime-type "$tmp_file" 2>/dev/null || true)"
  else
    mime_type=""
  fi
  if [ -z "$mime_type" ] || [ "$mime_type" = "application/octet-stream" ]; then
    case "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')" in
      jpg|jpeg) mime_type="image/jpeg" ;;
      png) mime_type="image/png" ;;
      gif) mime_type="image/gif" ;;
      webp) mime_type="image/webp" ;;
      *) mime_type="image/jpeg" ;;
    esac
  fi

  response=$(curl -sS -X POST \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    -F "file=@$tmp_file;filename=$filename;type=$mime_type" \
    "$base_url/wp-json/wp/v2/media")

  rm -f "$tmp_file"

  media_id="$(echo "$response" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2 || true)"
  if [ -z "$media_id" ]; then
    echo "Échec de l'upload: $image_url" >&2
    echo "$response" >&2
    return 1
  fi

  printf '%s' "$media_id"
}

# ============================================================================
# Fonctions utilitaires
# ============================================================================

# Vérifier si jq est disponible (parsing JSON robuste)
HAS_JQ=false
command -v jq >/dev/null 2>&1 && HAS_JQ=true

# Fonction pour lister les catégories
list_categories() {
  echo "Catégories disponibles:"
  echo ""
  local response
  response=$(curl -sS \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    "$WP_SITE_URL/wp-json/wp/v2/categories?per_page=100")

  if [ "$HAS_JQ" = true ]; then
    # Parsing robuste avec jq
    echo "$response" | jq -r '.[] | "  \(.name) (ID: \(.id))"' 2>/dev/null || echo "Erreur parsing JSON" >&2
  else
    # Fallback grep/sed (moins robuste avec emojis/caractères spéciaux)
    echo "$response" | grep -oE '\{"id":[0-9]+,"count":[0-9]+,"description":"[^"]*","link":"[^"]*","name":"[^"]+"' | \
      while read -r line; do
        local id name
        id=$(echo "$line" | grep -oE '"id":[0-9]+' | cut -d':' -f2)
        name=$(echo "$line" | grep -oE '"name":"[^"]+"' | sed 's/"name":"//;s/"$//')
        printf "  %-35s (ID: %s)\n" "$name" "$id"
      done
  fi
}

# Fonction pour trouver le prochain jour sans article
find_next_free_day() {
  local occupied_dates
  local check_date
  local days_ahead=1
  local max_days=60  # Chercher jusqu'à 60 jours dans le futur

  echo "Recherche du prochain jour libre..." >&2

  # Récupérer les posts publiés et programmés (future) des 60 prochains jours
  local after_date today_iso
  today_iso=$(date -u +"%Y-%m-%dT00:00:00")

  occupied_dates=$(curl -sS \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    "$WP_SITE_URL/wp-json/wp/v2/posts?status=publish,future&per_page=100&after=$today_iso" | \
    grep -oE '"date":"[0-9]{4}-[0-9]{2}-[0-9]{2}' | \
    cut -d'"' -f4 | \
    sort -u)

  # Chercher le premier jour libre
  while [ $days_ahead -le $max_days ]; do
    # Date à vérifier (demain + N jours)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      check_date=$(date -v+${days_ahead}d +"%Y-%m-%d")
    else
      check_date=$(date -d "+${days_ahead} days" +"%Y-%m-%d")
    fi

    # Vérifier si cette date est libre
    if ! echo "$occupied_dates" | grep -q "^$check_date$"; then
      echo "  → Jour libre trouvé: $check_date" >&2
      printf '%s' "$check_date"
      return 0
    fi

    ((days_ahead++))
  done

  # Si aucun jour libre trouvé, prendre le jour après le dernier
  echo "  ⚠ Aucun jour libre dans les $max_days prochains jours, utilisation de demain" >&2
  if [[ "$OSTYPE" == "darwin"* ]]; then
    date -v+1d +"%Y-%m-%d"
  else
    date -d "+1 day" +"%Y-%m-%d"
  fi
}

# Fonction pour convertir les noms de catégories en IDs
get_category_ids() {
  local cat_names="$1"
  local all_cats cat_ids=""

  all_cats=$(curl -sS \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    "$WP_SITE_URL/wp-json/wp/v2/categories?per_page=100")

  IFS=',' read -ra CATS <<< "$cat_names"
  for cat_name in "${CATS[@]}"; do
    cat_name=$(echo "$cat_name" | xargs) # trim whitespace
    local cat_id=""

    if [ "$HAS_JQ" = true ]; then
      # Parsing robuste avec jq (recherche partielle insensible à la casse)
      cat_id=$(echo "$all_cats" | jq -r --arg name "$cat_name" \
        '.[] | select(.name | test($name; "i")) | .id' 2>/dev/null | head -1)
    else
      # Fallback grep/sed (moins robuste)
      cat_id=$(echo "$all_cats" | grep -oE '\{"id":[0-9]+,"count":[0-9]+,"description":"[^"]*","link":"[^"]*","name":"[^"]+"' | \
        grep -i "$cat_name" | head -1 | grep -oE '"id":[0-9]+' | cut -d':' -f2)
    fi

    if [ -n "$cat_id" ]; then
      if [ -n "$cat_ids" ]; then
        cat_ids="$cat_ids,$cat_id"
      else
        cat_ids="$cat_id"
      fi
      echo "  → '$cat_name' trouvée (ID: $cat_id)" >&2
    else
      echo "  ⚠ '$cat_name' non trouvée, ignorée" >&2
    fi
  done

  printf '%s' "$cat_ids"
}

# Lister les catégories si demandé
if [ "$LIST_CATEGORIES" = true ]; then
  list_categories
  exit 0
fi

# Validation des paramètres requis
if [ -z "$TITLE" ]; then
  echo "Erreur: le titre est requis (-t)" >&2
  show_help
  exit 1
fi
if [ -z "$CONTENT" ]; then
  echo "Erreur: le contenu est requis (-c ou -f)" >&2
  show_help
  exit 1
fi
if [ -z "$IMAGE_URL" ]; then
  echo "Erreur: l'URL de l'image est requise (-i)" >&2
  show_help
  exit 1
fi

# Conversion Markdown → HTML
markdown_to_html() {
  local text="$1"

  # Blocs de code (``` ... ```)
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

  # Listes et titres (ligne par ligne)
  local in_list=false
  local result=""
  local IFS=$'\n'
  for line in $text; do
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

echo "Upload de l'image featured..."
FEATURED_MEDIA_ID=""
FEATURED_MEDIA_ID="$(upload_featured_media_from_url "$IMAGE_URL" || true)"

if [ -z "$FEATURED_MEDIA_ID" ]; then
  echo "Erreur: impossible d'uploader l'image" >&2
  exit 1
fi
echo "Image uploadée (ID: $FEATURED_MEDIA_ID)"

# Récupérer les IDs des catégories
CATEGORY_IDS=""
if [ -n "$CATEGORIES" ]; then
  echo "Recherche des catégories..."
  CATEGORY_IDS="$(get_category_ids "$CATEGORIES")"
  if [ -n "$CATEGORY_IDS" ]; then
    echo "Catégories trouvées: $CATEGORY_IDS"
  fi
fi

# Déterminer la date de publication suggérée
POST_STATUS="draft"
POST_DATE=""
POST_DATETIME=""

if [ "$DRAFT_MODE" = false ]; then
  # Mode avec date suggérée (reste en brouillon)
  if [ -n "$SCHEDULE_DATE" ]; then
    # Date spécifiée manuellement
    POST_DATE="$SCHEDULE_DATE"
  else
    # Trouver le prochain jour libre
    POST_DATE="$(find_next_free_day)"
  fi
  POST_DATETIME="${POST_DATE}T${SCHEDULE_HOUR}:00"
  echo "Création du brouillon pour le $POST_DATE à $SCHEDULE_HOUR..."
else
  echo "Création du brouillon..."
fi

# Construction du payload JSON
TITLE_ESCAPED="$(json_escape "$TITLE")"
CONTENT_ESCAPED="$(json_escape "$HTML_CONTENT")"

# Construire le JSON dynamiquement
JSON_PAYLOAD="{\"title\":\"$TITLE_ESCAPED\",\"content\":\"$CONTENT_ESCAPED\",\"status\":\"$POST_STATUS\",\"featured_media\":$FEATURED_MEDIA_ID"

# Ajouter la date si programmé
if [ -n "$POST_DATE" ]; then
  JSON_PAYLOAD="$JSON_PAYLOAD,\"date\":\"$POST_DATETIME\""
fi

# Ajouter le slug si fourni
if [ -n "$SLUG" ]; then
  SLUG_ESCAPED="$(json_escape "$SLUG")"
  JSON_PAYLOAD="$JSON_PAYLOAD,\"slug\":\"$SLUG_ESCAPED\""
fi

# Ajouter l'excerpt si fourni
if [ -n "$EXCERPT" ]; then
  EXCERPT_ESCAPED="$(json_escape "$EXCERPT")"
  JSON_PAYLOAD="$JSON_PAYLOAD,\"excerpt\":\"$EXCERPT_ESCAPED\""
fi

# Ajouter les catégories si trouvées
if [ -n "$CATEGORY_IDS" ]; then
  JSON_PAYLOAD="$JSON_PAYLOAD,\"categories\":[$CATEGORY_IDS]"
fi

# Ajouter les metas Jetpack Social
# - Message limité à 300 caractères
# - Image = réutilise la featured image (pas de doublon)
META_FIELDS=""

if [ -n "$SOCIAL_MSG" ]; then
  # Vérifier la limite de 300 caractères
  if [ ${#SOCIAL_MSG} -gt 300 ]; then
    echo "⚠ Message Jetpack Social tronqué à 300 caractères (était ${#SOCIAL_MSG})" >&2
    SOCIAL_MSG="${SOCIAL_MSG:0:297}..."
  fi
  SOCIAL_ESCAPED="$(json_escape "$SOCIAL_MSG")"
  META_FIELDS="\"jetpack_publicize_message\":\"$SOCIAL_ESCAPED\""
fi

# Toujours réutiliser la featured image pour Jetpack Social (attached_media)
if [ -n "$FEATURED_MEDIA_ID" ]; then
  # Récupérer l'URL de l'image pour Jetpack Social
  MEDIA_RESPONSE=$(curl -sS \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    "$WP_SITE_URL/wp-json/wp/v2/media/$FEATURED_MEDIA_ID")

  if [ "$HAS_JQ" = true ]; then
    MEDIA_URL=$(echo "$MEDIA_RESPONSE" | jq -r '.source_url // empty' 2>/dev/null)
  else
    MEDIA_URL=$(echo "$MEDIA_RESPONSE" | grep -oE '"source_url":"[^"]+"' | head -1 | cut -d'"' -f4)
  fi

  # Échapper l'URL pour JSON
  MEDIA_URL_ESCAPED="$(json_escape "$MEDIA_URL")"

  JETPACK_OPTIONS="{\"image_generator_settings\":{\"template\":\"highway\",\"enabled\":false},\"attached_media\":[{\"id\":$FEATURED_MEDIA_ID,\"url\":\"$MEDIA_URL_ESCAPED\",\"type\":\"image\"}],\"version\":2}"

  if [ -n "$META_FIELDS" ]; then
    META_FIELDS="$META_FIELDS,\"jetpack_social_post_already_shared\":false,\"jetpack_publicize_feature_enabled\":true,\"jetpack_social_options\":$JETPACK_OPTIONS"
  else
    META_FIELDS="\"jetpack_social_post_already_shared\":false,\"jetpack_publicize_feature_enabled\":true,\"jetpack_social_options\":$JETPACK_OPTIONS"
  fi
fi

if [ -n "$META_FIELDS" ]; then
  JSON_PAYLOAD="$JSON_PAYLOAD,\"meta\":{$META_FIELDS}"
fi

JSON_PAYLOAD="$JSON_PAYLOAD}"

RESPONSE=$(curl -sS -X POST \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -u "$WP_USERNAME:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$WP_SITE_URL/wp-json/wp/v2/posts")

if echo "$RESPONSE" | grep -q '"id"'; then
  POST_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
  POST_SLUG=$(echo "$RESPONSE" | grep -o '"slug":"[^"]*"' | head -n1 | cut -d'"' -f4)
  echo ""
  echo "Brouillon créé avec succès!"
  if [ -n "$POST_DATE" ]; then
    echo "Date suggérée: $POST_DATE à $SCHEDULE_HOUR"
  fi
  echo "ID: $POST_ID"
  echo "Slug: $POST_SLUG"
  echo "URL: $WP_SITE_URL/?p=$POST_ID"
  echo "Edit: $WP_SITE_URL/wp-admin/post.php?post=$POST_ID&action=edit"
else
  echo "Erreur lors de la création:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
