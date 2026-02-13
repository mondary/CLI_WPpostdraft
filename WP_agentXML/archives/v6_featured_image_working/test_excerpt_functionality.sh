#!/bin/bash

# Test Excerpt Functionality
echo "=== Testing Excerpt Functionality ==="

# Change to main directory and run test
cd "$(dirname "$0")/.."

# Test with excerpt to verify it's properly set
./wp_post_draft.sh --auto << EOF
Test Article avec Excerpt
test-article-excerpt
Ceci est un **excerpt de test** qui devrait apparaître comme résumé de l'article dans WordPress. Il sera visible dans les listes d'articles et utilisé pour le SEO.
https://github.com/Owloops/updo/raw/main/images/demo.png
Article de test pour vérifier la **fonctionnalité excerpt**.

## Introduction

L'excerpt devrait être défini séparément du contenu principal.

## Test de l'excerpt

Cet article teste le nouveau champ excerpt qui a été ajouté au script.

### Vérifications à faire :

- ✅ L'excerpt apparaît dans le résumé du script
- ✅ L'excerpt est défini dans WordPress admin
- ✅ L'excerpt apparaît dans les listes d'articles
- ✅ L'excerpt est utilisé pour les previews

---

**Important :** Vérifiez dans WordPress admin que l'excerpt est bien rempli automatiquement.

END
EOF

echo ""
echo "🔍 Excerpt test completed!"
echo ""
echo "📋 Verification steps:"
echo "1. Go to WordPress Admin → Posts"
echo "2. Open the created post"
echo "3. Look for the 'Excerpt' field in the editor"
echo "4. Check if it contains: 'Ceci est un excerpt de test...'"
echo "5. In post list, verify the excerpt appears in preview"
echo ""
echo "If excerpt appears → ✅ Excerpt functionality is working!"
echo "If no excerpt → ❌ Check XML-RPC excerpt field implementation"