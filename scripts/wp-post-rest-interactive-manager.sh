#!/bin/bash
set -euo pipefail

# Interactive manager for WordPress posts through REST API.
# Features: create, list latest, publish draft by ID.

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

show_menu() {
  echo ""
  echo "=== WordPress REST Post Manager ==="
  echo "1) Create post"
  echo "2) List latest posts"
  echo "3) Publish draft by ID"
  echo "4) Exit"
  printf "Choice: "
}

create_post() {
  printf "Title: "
  read -r title
  printf "Content: "
  read -r content
  printf "Status [draft]: "
  read -r status
  status="${status:-draft}"
  if ! validate_post_status "$status"; then
    return 1
  fi

  title_escaped="$(json_escape "$title")"
  content_escaped="$(json_escape "$content")"
  payload="{\"title\":{\"raw\":\"$title_escaped\"},\"content\":{\"raw\":\"$content_escaped\"},\"status\":\"$status\"}"

  response=$(curl -sS -X POST \
    -H "User-Agent: WP-CLI-OLD" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$WP_SITE_URL/wp-json/wp/v2/posts")

  if echo "$response" | grep -q '"id"'; then
    post_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
    echo "Post created"
    echo "ID: $post_id"
    echo "Status: $status"
    echo "URL: $WP_SITE_URL/?p=$post_id"
  else
    echo "Creation failed"
    echo "$response"
    return 1
  fi
}

list_posts() {
  response=$(curl -sS \
    -H "User-Agent: WP-CLI-OLD" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    "$WP_SITE_URL/wp-json/wp/v2/posts?per_page=10&context=edit")

  if command -v jq >/dev/null 2>&1; then
    echo "$response" | jq -r '.[] | "ID: \(.id) | \(.status) | \(.title.rendered)"'
  else
    echo "jq not found. Raw JSON below:"
    echo "$response"
  fi
}

publish_draft() {
  printf "Draft post ID to publish: "
  read -r post_id

  response=$(curl -sS -X POST \
    -H "User-Agent: WP-CLI-OLD" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{"status":"publish"}' \
    "$WP_SITE_URL/wp-json/wp/v2/posts/$post_id")

  if echo "$response" | grep -q '"status":"publish"'; then
    echo "Post published"
    echo "URL: $WP_SITE_URL/?p=$post_id"
  else
    echo "Publish failed"
    echo "$response"
    return 1
  fi
}

while true; do
  show_menu
  read -r choice
  case "$choice" in
    1) create_post ;;
    2) list_posts ;;
    3) publish_draft ;;
    4) exit 0 ;;
    *) echo "Invalid choice" ;;
  esac
done
