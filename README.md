# CLI_WPpostdraft

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

Scripts WordPress centralisés dans `scripts/` avec un fichier credentials unique dans `secrets/`.

## Structure
- Scripts: `scripts/`
- Credentials: `secrets/wp-credentials`
- Exemple de fichier article: `scripts/article_data.example.txt`

## Credentials
Fichier attendu: `secrets/wp-credentials`

Format (3 lignes):
1. `https://votre-site.tld`
2. `votre-username`
3. `votre-application-password`

## Fonctionnement script par script
`scripts/secrets.sh`
- Rôle: charge les credentials pour les scripts REST.
- Source: `../secrets/wp-credentials` (ou variable `WP_CLI_OLD_CONFIG_FILE`).
- Exporte: `WP_SITE_URL`, `WP_USERNAME`, `WP_APP_PASSWORD`.

`scripts/wp-post-rest-title-content.sh`
- Méthode: REST API (`/wp-json/wp/v2/posts`).
- Entrée: `title`, `content`, `status` optionnel.
- Statut par défaut: `draft`.
- Usage:
```bash
./scripts/wp-post-rest-title-content.sh "Titre" "Contenu" draft
```

`scripts/wp-post-rest-app-template.sh`
- Méthode: REST API.
- Entrée: `app_name`, `description`, `url`, `details`, `image_url` optionnelle, `status` optionnel.
- Statut par défaut: `draft`.
- Génère automatiquement un contenu HTML type "fiche app".
- Si `image_url` est fournie:
1. tente un upload REST dans la médiathèque pour définir `featured_media`,
2. si l’upload REST est bloqué (ex: HTTP 403), applique un fallback XML-RPC (meta plugin featured URL).
- Usage:
```bash
./scripts/wp-post-rest-app-template.sh "Nom App" "desc courte" "https://app.tld" "détails" "" draft
```

`scripts/wp-post-rest-app-template-with-excerpt.sh`
- Méthode: REST API.
- Entrée: `app_name`, `description`, `url`, `image_url`, `details`, `status` optionnel.
- Statut par défaut: `draft`.
- Ajoute aussi `excerpt` et la meta `jetpack_publicize_message`.
- Si `image_url` est fournie: même logique featured que ci-dessus (REST media, puis fallback XML-RPC en cas d’échec).
- Usage:
```bash
./scripts/wp-post-rest-app-template-with-excerpt.sh "Nom App" "desc" "https://app.tld" "https://img.tld/a.jpg" "<ul><li>point</li></ul>" draft
```

`scripts/wp-post-rest-app-from-file.sh`
- Méthode: REST API.
- Entrée: fichier texte (défaut: `scripts/article_data.txt`).
- Format fichier:
1. APP_NAME
2. SHORT_DESCRIPTION
3. URL
4. IMAGE_URL
5. DETAILS_HTML_OR_TEXT
6. STATUS (optionnel, vide = `draft`)
- Usage:
```bash
./scripts/wp-post-rest-app-from-file.sh scripts/article_data.txt
```
- Ligne 4 (`IMAGE_URL`) déclenche la même logique featured (REST media puis fallback XML-RPC).

`scripts/wp-post-rest-interactive-manager.sh`
- Méthode: REST API interactive.
- Menu:
1. Créer un post
2. Lister les 10 derniers posts
3. Publier un draft par ID
4. Quitter
- Attention: ce script peut publier en direct si tu utilises l’option `3`.
- Usage:
```bash
./scripts/wp-post-rest-interactive-manager.sh
```

`scripts/wp-post-xmlrpc-draft-featured-plugin-url.sh`
- Méthode: XML-RPC (`wp.newPost` puis `wp.editPost`).
- Crée un post en `draft`.
- Si `-i` est une URL, définit l’image featured via méta URL (plugin "Featured Image by URL").
- Entrées principales: `-t/--title`, `-c/--content`, `-i/--image`, `--categories`, `-e/--excerpt`, `-u/--slug`, `--dry-run`.
- Usage:
```bash
./scripts/wp-post-xmlrpc-draft-featured-plugin-url.sh -t "Titre" -c "Contenu" -i "https://img.tld/a.jpg"
```

`scripts/wp-post-xmlrpc-draft-featured-native-upload.sh`
- Méthode: XML-RPC (`wp.newPost` + upload media + association featured image).
- Crée un post en `draft`.
- Si `-i` est une URL, télécharge l’image puis l’upload dans WordPress et l’associe comme featured image.
- Entrées principales: `-t/--title`, `-c/--content`, `-i/--image`, `--categories`, `-e/--excerpt`, `-u/--slug`, `--dry-run`.
- Usage:
```bash
./scripts/wp-post-xmlrpc-draft-featured-native-upload.sh -t "Titre" -c "Contenu" -i "https://img.tld/a.jpg"
```

`scripts/wp-post-xmlrpc-test-validate-image-url.sh`
- Rôle: script de test local d'une fonction de validation d'URL image.
- Ne crée pas de post WordPress.
- Usage:
```bash
./scripts/wp-post-xmlrpc-test-validate-image-url.sh
```

`scripts/wp-post-draft-featured.sh`
- Méthode: REST API.
- Rôle: créer un brouillon simple avec une featured image.
- Entrée: `titre`, `contenu`, `url_image`.
- Statut: toujours `draft`.
- Usage:
```bash
./scripts/wp-post-draft-featured.sh "Mon Titre" "Mon contenu texte" "https://example.com/image.jpg"
```

`scripts/wp-post-draft-featured-markdown.sh`
- Méthode: REST API.
- Rôle: créer un brouillon avec featured image et contenu **Markdown**.
- Entrée: `titre`, `contenu_markdown` ou `-f fichier.md`, `url_image`.
- Statut: toujours `draft`.
- Markdown supporté:
  | Syntaxe | Résultat |
  |---------|----------|
  | `# Titre` | Titre h1 |
  | `## Titre` | Titre h2 (jusqu'à h6) |
  | `**gras**` | Texte en gras |
  | `*italique*` | Texte en italique |
  | `` `code` `` | Code inline |
  | ` ```code``` ` | Bloc de code |
  | `- item` | Liste à puces |
  | `[texte](url)` | Lien cliquable |
  | `![alt](url)` | Image |
  | URL YouTube | Embed vidéo |
- Usage (contenu direct):
```bash
./scripts/wp-post-draft-featured-markdown.sh "Mon Titre" "## Introduction

Voici un texte **important** avec du \`code\`.

- Point 1
- Point 2

[Lien](https://example.com)" "https://example.com/image.jpg"
```
- Usage (depuis fichier):
```bash
./scripts/wp-post-draft-featured-markdown.sh "Mon Titre" -f article.md "https://example.com/image.jpg"
```

`scripts/wp-post-draft-full.sh`
- Méthode: REST API.
- Rôle: script **complet et autonome** pour créer des brouillons WordPress.
- **Script autonome**: ne dépend d'aucun autre script (credentials intégrés).
- **Par défaut**: trouve le **prochain jour sans article** et suggère cette date.
- **Toujours en brouillon** (jamais planifié automatiquement).
- Fonctionnalités:
  - Featured image
  - Contenu Markdown (titres, gras, italique, code, listes, liens, images, YouTube)
  - Slug personnalisé (optionnel, auto-généré si vide)
  - Excerpt (extrait)
  - Jetpack Social (message max 300 car. + image attachée)
  - Catégories (par nom, recherche partielle)
  - **Date intelligente** (trouve le prochain jour libre)
- Options:
  | Option | Description |
  |--------|-------------|
  | `-t, --title` | Titre du post (requis) |
  | `-c, --content` | Contenu Markdown (requis) |
  | `-i, --image` | URL image featured (requis) |
  | `-f, --file` | Lire contenu depuis fichier .md |
  | `-s, --slug` | Slug personnalisé |
  | `-e, --excerpt` | Extrait du post |
  | `-j, --social` | Message Jetpack Social (max 300 car.) |
  | `-C, --categories` | Catégories (noms séparés par virgule) |
  | `--list-categories` | Lister les catégories disponibles |
  | `--draft` | Brouillon simple (sans date suggérée) |
  | `-d, --date` | Date spécifique (YYYY-MM-DD) |
  | `--hour` | Heure suggérée (défaut: 09:00) |
- Usage:
```bash
# Lister les catégories disponibles
./scripts/wp-post-draft-full.sh --list-categories

# Brouillon avec date au prochain jour libre (DÉFAUT)
./scripts/wp-post-draft-full.sh \
  -t "Mon Article" \
  -c "## Intro\n\nTexte **important**" \
  -i "https://example.com/image.jpg" \
  -e "Résumé de l'article" \
  -j "Découvrez mon nouvel article! #hashtag" \
  -C "NoCode,Tools"

# Brouillon simple sans date
./scripts/wp-post-draft-full.sh \
  -t "Mon Article" \
  -c "Contenu" \
  -i "https://example.com/image.jpg" \
  --draft

# Brouillon avec date spécifique
./scripts/wp-post-draft-full.sh \
  -t "Mon Article" \
  -c "Contenu" \
  -i "https://example.com/image.jpg" \
  -d "2026-03-15" \
  --hour "14:30"

# Avec contenu depuis fichier
./scripts/wp-post-draft-full.sh \
  -t "Mon Article" \
  -f article.md \
  -i "https://example.com/image.jpg" \
  -C "Article"
```

`scripts/rest-featured-media.sh`
- Rôle: module partagé pour l'upload d'images dans la médiathèque WordPress.
- Fonction principale: `upload_featured_media_from_url()` - télécharge une image depuis une URL et l'upload via REST API.
- Fonction fallback: `set_featured_image_url_via_xmlrpc()` - définit l'image featured via XML-RPC (plugin meta).
- Ce script est sourcé par les autres scripts, il ne s'utilise pas directement.

## Résumé draft vs publish
- Scripts REST non interactifs: draft par défaut, publication directe possible uniquement si tu passes `publish` explicitement.
- Script interactif REST: peut publier via menu option `3`.
- Scripts XML-RPC ci-dessus: créent en `draft` (avec option `--dry-run` possible pour simuler).

## Test rapide (safe)
```bash
cd /Users/clm/Documents/GitHub/PROJECTS/CLI_WPpostdraft
chmod +x scripts/*.sh
./scripts/wp-post-rest-title-content.sh "Test draft $(date +%F-%T)" "Test README" draft
```
