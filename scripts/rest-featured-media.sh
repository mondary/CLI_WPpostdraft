#!/bin/bash
set -euo pipefail

# Upload an image URL to WordPress media library and return media ID.
# Requires: WP_SITE_URL, WP_USERNAME, WP_APP_PASSWORD

upload_featured_media_from_url() {
  local image_url="$1"
  if [ -z "$image_url" ]; then
    echo "Missing image URL for media upload" >&2
    return 1
  fi
  if [[ ! "$image_url" =~ ^https?:// ]]; then
    echo "Only HTTP(S) image URLs are supported for featured media: $image_url" >&2
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
    echo "Failed to download image URL: $image_url" >&2
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
      bmp) mime_type="image/bmp" ;;
      svg) mime_type="image/svg+xml" ;;
      *) mime_type="image/jpeg" ;;
    esac
  fi

  response=$(curl -sS -X POST \
    -H "User-Agent: WP-CLI-OLD" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    -H "Content-Disposition: attachment; filename=\"$filename\"" \
    -H "Content-Type: $mime_type" \
    --data-binary @"$tmp_file" \
    "$base_url/wp-json/wp/v2/media")

  rm -f "$tmp_file"

  media_id="$(echo "$response" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2 || true)"
  if [ -z "$media_id" ]; then
    echo "Media upload failed for URL: $image_url" >&2
    echo "$response" >&2
    return 1
  fi

  printf '%s' "$media_id"
}

xml_escape() {
  local s="$1"
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  s=${s//\'/&apos;}
  printf '%s' "$s"
}

set_featured_image_url_via_xmlrpc() {
  local post_id="$1"
  local image_url="$2"
  local base_url response xml_payload
  base_url="${WP_SITE_URL%/}"

  if [ -z "$post_id" ] || [ -z "$image_url" ]; then
    echo "Missing post_id or image_url for XML-RPC featured URL fallback" >&2
    return 1
  fi

  xml_payload="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<methodCall>
  <methodName>wp.editPost</methodName>
  <params>
    <param><value><string>0</string></value></param>
    <param><value><string>$(xml_escape "$WP_USERNAME")</string></value></param>
    <param><value><string>$(xml_escape "$WP_APP_PASSWORD")</string></value></param>
    <param><value><int>$post_id</int></value></param>
    <param><value><struct>
      <member>
        <name>custom_fields</name>
        <value><array><data>
          <value><struct>
            <member><name>key</name><value><string>_knawatfibu_url</string></value></member>
            <member><name>value</name><value><string>$(xml_escape "$image_url")</string></value></member>
          </struct></value>
          <value><struct>
            <member><name>key</name><value><string>_knawatfibu_alt</string></value></member>
            <member><name>value</name><value><string>Featured Image</string></value></member>
          </struct></value>
        </data></array></value>
      </member>
    </struct></value></param>
  </params>
</methodCall>"

  response="$(curl -sS -X POST \
    -H "Content-Type: text/xml" \
    -H "User-Agent: wp-draft.sh/1.0" \
    --connect-timeout 30 \
    --max-time 60 \
    --data "$xml_payload" \
    "$base_url/xmlrpc.php")"

  if echo "$response" | grep -q "<boolean>1</boolean>"; then
    return 0
  fi

  echo "XML-RPC featured URL fallback failed for post $post_id" >&2
  echo "$response" >&2
  return 1
}
