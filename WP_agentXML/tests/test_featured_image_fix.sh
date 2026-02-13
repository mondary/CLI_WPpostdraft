#!/bin/bash

# Test Featured Image Functionality
echo "=== Testing Featured Image with Jetpack Social ==="

# Change to main directory and run test
cd "$(dirname "$0")/.."

# Test with featured image URL and excerpt for Jetpack Social
./wp_post_draft.sh --auto << EOF
Test Featured Image Fix
test-featured-image-fix
🖼️ Test de l'image à la une avec intégration Jetpack Social ! L'image doit s'afficher correctement. #WordPress #FeaturedImage
https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=1200&h=630&fit=crop&auto=format
# Test **Featured Image** avec Jetpack Social

Ce test vérifie que l'**image à la une** s'affiche correctement.

## ✅ Vérifications

### Image à la Une
- **URL**: Unsplash (1200x630px)
- **Affichage**: Doit apparaître dans WordPress admin
- **Jetpack Social**: Doit être utilisée comme image d'accompagnement

### Jetpack Social
- **Message**: Excerpt avec émojis et hashtags
- **Image**: Featured image automatiquement attachée

---

**Test réussi si l'image à la une est visible dans WordPress admin !**

END
EOF

echo ""
echo "🔍 Featured image test completed!"
echo ""
echo "📋 Verification steps:"
echo "1. Go to WordPress Admin → Posts"
echo "2. Open the created post"
echo "3. Check if featured image is displayed in the sidebar"
echo "4. Verify the image appears in post list thumbnails"
echo "5. Check Jetpack Social settings show the image"
echo ""
echo "✅ If featured image is visible → Fix successful!"
echo "❌ If no featured image → Check WPCode installation and custom fields"