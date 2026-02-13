# CLI_WPpostdraft

[🇬🇧 EN](README_en.md) · [🇫🇷 FR](README.md)

WordPress scripts are centralized in `scripts/` with one shared credentials file in `secrets/`.

## Structure
- Scripts: `scripts/`
- Credentials: `secrets/wp-credentials`
- Article file example: `scripts/article_data.example.txt`

## Credentials
Expected file: `secrets/wp-credentials`

3-line format:
1. `https://your-site.tld`
2. `your-username`
3. `your-application-password`

## Script-by-script behavior
`scripts/secrets.sh`
- Purpose: loads credentials for REST scripts.
- Source: `../secrets/wp-credentials` (or `WP_CLI_OLD_CONFIG_FILE`).
- Exports: `WP_SITE_URL`, `WP_USERNAME`, `WP_APP_PASSWORD`.

`scripts/wp-post-rest-title-content.sh`
- Method: REST API (`/wp-json/wp/v2/posts`).
- Input: `title`, `content`, optional `status`.
- Default status: `draft`.
- Usage:
```bash
./scripts/wp-post-rest-title-content.sh "Title" "Content" draft
```

`scripts/wp-post-rest-app-template.sh`
- Method: REST API.
- Input: `app_name`, `description`, `url`, `details`, optional `image_url`, optional `status`.
- Default status: `draft`.
- Builds HTML content in app-card style.
- If `image_url` is provided:
1. it first tries REST media upload to set `featured_media`,
2. if REST upload is blocked (for example HTTP 403), it falls back to XML-RPC featured URL meta.
- Usage:
```bash
./scripts/wp-post-rest-app-template.sh "App Name" "short desc" "https://app.tld" "details" "" draft
```

`scripts/wp-post-rest-app-template-with-excerpt.sh`
- Method: REST API.
- Input: `app_name`, `description`, `url`, `image_url`, `details`, optional `status`.
- Default status: `draft`.
- Also sets `excerpt` and `jetpack_publicize_message` meta.
- If `image_url` is provided: same featured logic as above (REST media first, XML-RPC fallback on failure).
- Usage:
```bash
./scripts/wp-post-rest-app-template-with-excerpt.sh "App Name" "desc" "https://app.tld" "https://img.tld/a.jpg" "<ul><li>point</li></ul>" draft
```

`scripts/wp-post-rest-app-from-file.sh`
- Method: REST API.
- Input: text file (default: `scripts/article_data.txt`).
- File format:
1. APP_NAME
2. SHORT_DESCRIPTION
3. URL
4. IMAGE_URL
5. DETAILS_HTML_OR_TEXT
6. STATUS (optional, empty = `draft`)
- Usage:
```bash
./scripts/wp-post-rest-app-from-file.sh scripts/article_data.txt
```
- Line 4 (`IMAGE_URL`) triggers the same featured logic (REST media, then XML-RPC fallback).

`scripts/wp-post-rest-interactive-manager.sh`
- Method: interactive REST API menu.
- Menu:
1. Create post
2. List last 10 posts
3. Publish draft by ID
4. Exit
- Warning: this script can publish live if you choose menu option `3`.
- Usage:
```bash
./scripts/wp-post-rest-interactive-manager.sh
```

`scripts/wp-post-xmlrpc-draft-featured-plugin-url.sh`
- Method: XML-RPC (`wp.newPost` then `wp.editPost`).
- Creates post as `draft`.
- If `-i` is a URL, sets featured image URL meta (plugin "Featured Image by URL").
- Main options: `-t/--title`, `-c/--content`, `-i/--image`, `--categories`, `-e/--excerpt`, `-u/--slug`, `--dry-run`.
- Usage:
```bash
./scripts/wp-post-xmlrpc-draft-featured-plugin-url.sh -t "Title" -c "Content" -i "https://img.tld/a.jpg"
```

`scripts/wp-post-xmlrpc-draft-featured-native-upload.sh`
- Method: XML-RPC (`wp.newPost` + media upload + featured image association).
- Creates post as `draft`.
- If `-i` is a URL, downloads the image, uploads it to WordPress, then sets it as featured image.
- Main options: `-t/--title`, `-c/--content`, `-i/--image`, `--categories`, `-e/--excerpt`, `-u/--slug`, `--dry-run`.
- Usage:
```bash
./scripts/wp-post-xmlrpc-draft-featured-native-upload.sh -t "Title" -c "Content" -i "https://img.tld/a.jpg"
```

`scripts/wp-post-xmlrpc-test-validate-image-url.sh`
- Purpose: local validation test for image URL checking function.
- Does not create WordPress posts.
- Usage:
```bash
./scripts/wp-post-xmlrpc-test-validate-image-url.sh
```

`scripts/wp-post-draft-featured.sh`
- Method: REST API.
- Purpose: create a simple draft with a native featured image.
- Input: `title`, `content`, `image_url`.
- Status: always `draft`.
- Usage:
```bash
./scripts/wp-post-draft-featured.sh "My Title" "My post content" "https://example.com/image.jpg"
```

`scripts/wp-post-draft-featured-markdown.sh`
- Method: REST API.
- Purpose: create a draft with native featured image and Markdown-to-HTML content conversion.
- Input: `title`, `markdown_content` OR `-f file.md`, `image_url`.
- Status: always `draft`.
- Supports headings, bold/italic, inline code/code blocks, lists, links, images, and YouTube embeds.
- Usage (inline content):
```bash
./scripts/wp-post-draft-featured-markdown.sh "My Title" "## Intro\n\n**Important** text" "https://example.com/image.jpg"
```
- Usage (from file):
```bash
./scripts/wp-post-draft-featured-markdown.sh "My Title" -f article.md "https://example.com/image.jpg"
```

`scripts/wp-post-draft-full.sh`
- Method: REST API.
- Purpose: full all-in-one draft workflow (featured image, Markdown, slug, excerpt, Jetpack message, categories, suggested date).
- Status: always `draft`.
- Date behavior:
1. default: finds next free day and sets a suggested date/time while keeping status `draft`,
2. `--draft`: creates a plain draft without suggested date.
- Key options: `-t`, `-c` or `-f`, `-i`, `-s`, `-e`, `-j`, `-C`, `--list-categories`, `--draft`, `-d`, `--hour`.
- Usage:
```bash
./scripts/wp-post-draft-full.sh -t "My Post" -c "## Intro" -i "https://example.com/image.jpg" -C "NoCode,Tools"
```

`scripts/rest-featured-media.sh`
- Purpose: shared helper sourced by other scripts.
- Main function: `upload_featured_media_from_url()` uploads an image URL to WP media and returns media ID.
- Fallback function: `set_featured_image_url_via_xmlrpc()` writes featured URL meta via XML-RPC.
- Not intended to be run directly.

## Draft vs publish summary
- Non-interactive REST scripts: default to draft, publish only if `publish` is explicitly passed.
- Interactive REST manager: can publish via menu option `3`.
- XML-RPC scripts above: create drafts (with optional `--dry-run` simulation mode).

## Quick safe test
```bash
cd /Users/clm/Documents/GitHub/PROJECTS/CLI_WPpostdraft
chmod +x scripts/*.sh
./scripts/wp-post-rest-title-content.sh "Draft test $(date +%F-%T)" "README test" draft
```
