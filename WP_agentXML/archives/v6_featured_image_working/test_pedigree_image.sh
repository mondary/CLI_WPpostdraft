#!/bin/bash

# Test Featured Image with Pedigree URL
echo "=== Testing Featured Image with Pedigree URL ==="

# Change to main directory and run test
cd "$(dirname "$0")/.."

# Test with the specific Pedigree URL
./wp_post_draft.sh --auto << EOF
Test Featured Image - URL Pedigree
test-featured-image-pedigree-$(date +%s)
Test avec l'URL d'image Pedigree pour vérifier la featured image.
https://www.pedigree.fr/cdn-cgi/image/format=auto,q=90/sites/g/files/fnmzdf5206/files/2023-06/yasmine-duchesne-deFc953RSP4-unsplash.jpg
# Test Featured Image avec URL Pedigree

Ce test utilise l'URL d'image spécifique Pedigree.

## Image testée
**URL**: https://www.pedigree.fr/cdn-cgi/image/format=auto,q=90/sites/g/files/fnmzdf5206/files/2023-06/yasmine-duchesne-deFc953RSP4-unsplash.jpg

## Fonctionnement attendu
1. Script crée le post avec custom field
2. WPCode télécharge l'image
3. Featured image apparaît dans WordPress

---

**Résultat attendu**: Featured image visible dans l'admin.

END
EOF

echo ""
echo "✅ Test completed! Check WordPress admin for the featured image."