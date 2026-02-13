# CLI_WPpostdraft

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

Scripts WordPress regroupés dans `scripts/`, avec un fichier secret unique: `secrets/wp-credentials`.

## ✅ Fonctionnalités
- Tous les scripts actifs sont dans `scripts/`.
- Une seule source de credentials pour REST + XML-RPC.
- Plusieurs modes: titre/contenu, template app, fichier, interactif, XML-RPC.

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

## ⚙️ Credentials (fichier unique)
Fichier: `secrets/wp-credentials`

Format (3 lignes):
1. URL du site
2. Nom d'utilisateur
3. Application password

## 🧾 Test draft rapide
```bash
cd /Users/clm/Documents/GitHub/PROJECTS/CLI_WPpostdraft
chmod +x scripts/*.sh
./scripts/wp-post-rest-title-content.sh "Test draft $(date +%F-%T)" "Contenu test" draft
```

## 🔗 Liens
- EN README: `README_en.md`
- Détails scripts: `scripts/README.md`
