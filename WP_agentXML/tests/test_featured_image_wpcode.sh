#!/bin/bash

# Test Featured Image with User's WPCode
echo "=== Test Featured Image avec WPCode Utilisateur ==="

cd "$(dirname "$0")/.."

echo ""
echo "🖼️ Test de la featured image avec votre WPCode snippet"
echo ""
echo "⚠️  PRÉREQUIS OBLIGATOIRES :"
echo "1. WPCode plugin installé et activé"
echo "2. Votre snippet featured image ajouté et ACTIVÉ dans WPCode"
echo "3. Snippet utilisant le hook 'save_post'"
echo ""

echo "📝 Création du post de test..."

# Test avec une image Unsplash fiable
echo "Test Featured Image WPCode
test-featured-image-wpcode
Test de l'image mise en avant avec WPCode
https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=400
Ce post teste la **featured image** avec votre WPCode snippet.

## Comment ça marche

1. Le script crée le post avec le custom field \`featured_image_url\`
2. Votre WPCode détecte ce field lors de la sauvegarde
3. Il télécharge l'image et la définit comme featured image

### Test en cours...

Cette image devrait apparaître comme featured image après sauvegarde manuelle.

END" | ./wp_post_draft.sh --auto

echo ""
echo "✅ Post créé !"
echo ""
echo "🔧 ÉTAPES OBLIGATOIRES pour activer la featured image :"
echo ""
echo "1. **Allez dans WordPress Admin → Posts**"
echo "2. **Trouvez le post 'Test Featured Image WPCode'**"
echo "3. **Cliquez 'Edit' pour l'éditer**"
echo "4. **Cliquez 'Update' (même sans rien modifier)**"
echo "5. **→ La featured image devrait apparaître automatiquement**"
echo ""
echo "🔍 Vérification :"
echo "• Dans l'éditeur, vous devriez voir l'image dans le bloc 'Featured Image'"
echo "• Sur le site, l'image devrait s'afficher avec le post"
echo ""
echo "❌ Si ça ne fonctionne pas :"
echo "• Vérifiez que votre WPCode snippet est ACTIVÉ"
echo "• Vérifiez les logs WordPress pour les erreurs PHP"
echo "• Essayez avec une autre image URL"
echo ""
echo "🖼️ Image de test utilisée :"
echo "https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800&h=400"