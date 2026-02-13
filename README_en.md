# CLI_WPpostdraft

[🇬🇧 EN](README_en.md) · [🇫🇷 FR](README.md)

WordPress scripts are centralized in `scripts/`, using a single shared credentials file: `secrets/wp-credentials`.

## ✅ Features
- All active scripts are in `scripts/`.
- One credentials source for REST and XML-RPC.
- Multiple workflows: title/content, app templates, file mode, interactive mode, XML-RPC mode.

## 🧠 Scripts
### REST
- `scripts/wp-post-rest-title-content.sh`
- `scripts/wp-post-rest-title-content-legacy.sh`
- `scripts/wp-post-rest-app-template.sh`
- `scripts/wp-post-rest-app-template-with-excerpt.sh`
- `scripts/wp-post-rest-app-from-file.sh`
- `scripts/wp-post-rest-interactive-manager.sh`
- `scripts/secrets.sh`

### XML-RPC
- `scripts/wp-post-xmlrpc-draft-upload-image.sh`
- `scripts/wp-post-xmlrpc-draft-featured-url.sh`
- `scripts/wp-post-xmlrpc-test-validate-image-url.sh`

## ⚙️ Credentials (single file)
File: `secrets/wp-credentials`

Format (3 lines):
1. Site URL
2. Username
3. Application password

## 🧾 Quick draft test
```bash
cd /Users/clm/Documents/GitHub/PROJECTS/CLI_WPpostdraft
chmod +x scripts/*.sh
./scripts/wp-post-rest-title-content.sh "Draft test $(date +%F-%T)" "Test content" draft
```

## 🔗 Links
- FR README: `README.md`
- Script details: `scripts/README.md`
