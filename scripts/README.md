# scripts

All active WordPress scripts are centralized here.

## Shared credentials (single source)
All scripts use one shared file: `../secrets/wp-credentials`

Format (3 lines):
1. Site URL
2. Username
3. Application password

## REST scripts
- `wp-post-rest-title-content.sh`
- `wp-post-rest-title-content-legacy.sh`
- `wp-post-rest-app-template.sh`
- `wp-post-rest-app-template-with-excerpt.sh`
- `wp-post-rest-app-from-file.sh`
- `wp-post-rest-interactive-manager.sh`
- `secrets.sh` (shared loader)

## XML-RPC scripts
- `wp-post-xmlrpc-draft-upload-image.sh`
- `wp-post-xmlrpc-draft-featured-url.sh`
- `wp-post-xmlrpc-test-validate-image-url.sh`

## Data templates
- `article_data.example.txt`
