#!/bin/bash

# Test Jetpack Social Integration
echo "=== Testing Jetpack Social Integration ==="

# Change to main directory and run test
cd "$(dirname "$0")/.."

# Test with excerpt and featured image to verify Jetpack Social integration
./wp_post_draft.sh --auto << EOF
Test Article avec Jetpack Social Integration
test-jetpack-social-integration
Ceci est un message Jetpack Social qui devrait apparaître sur tous vos réseaux sociaux connectés ! 🚀 #WordPress #JetpackSocial
https://github.com/Owloops/updo/raw/main/images/demo.png
Article de test pour vérifier l'**intégration Jetpack Social**.

## Fonctionnalités testées

Cette article teste la nouvelle intégration **Jetpack Social** qui synchronise :

### ✅ Excerpt → Message Social
- L'excerpt devient automatiquement le message personnalisé
- Limite de 255 caractères respectée
- Émojis et hashtags supportés

### ✅ Featured Image → Media Joint
- L'image à la une devient l'image des réseaux sociaux
- Compatible avec les URLs et fichiers locaux
- Optimisée pour tous les réseaux (Facebook, Twitter, LinkedIn, etc.)

## Comment vérifier

1. **Dans WordPress Admin** :
   - Allez dans Posts → Modifier ce post
   - Vérifiez l'excerpt dans la sidebar
   - Confirmez la featured image

2. **Jetpack Social (si configuré)** :
   - Allez dans Jetpack → Social
   - Vérifiez que le message personnalisé correspond à l'excerpt
   - Confirmez que l'image est bien attachée

3. **Post Meta** :
   - Custom field `_wpas_mess` doit contenir l'excerpt
   - Custom field `featured_image_url` (si URL utilisée)

---

**Test réussi si** : Excerpt = Message social ET Featured image = Media joint 🎯

END
EOF

echo ""
echo "🔍 Jetpack Social integration test completed!"
echo ""
echo "📋 Verification steps:"
echo "1. Go to WordPress Admin → Posts"
echo "2. Open the created post"
echo "3. Check Jetpack Social section in the sidebar"
echo "4. Verify custom message matches the excerpt"
echo "5. Confirm featured image is set for social sharing"
echo ""
echo "🔧 Advanced verification:"
echo "1. Go to Posts → Custom Fields view"
echo "2. Look for '_wpas_mess' field with excerpt value"
echo "3. Look for 'featured_image_url' field (if URL was used)"
echo ""
echo "✅ If both excerpt and featured image appear in Jetpack Social → Integration working!"
echo "❌ If not → Check Jetpack Social plugin activation and connection"