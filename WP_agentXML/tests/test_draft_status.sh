#!/bin/bash

# Test Draft Status (Version Stable)
echo "=== Test Statut Brouillon (Version Stable V5) ==="

cd "$(dirname "$0")/.."

echo ""
echo "🎯 Utilisation de wp_post_draft_v5 (version stable)"
echo "💡 Cette version ne devrait créer QUE des brouillons"
echo ""

# Test simple avec version stable
echo -e "Test Brouillon Stable\ntest-brouillon-stable\nTest de statut\n\nCeci est un test pour vérifier que le post reste en BROUILLON.\n\nIl ne doit PAS être publié automatiquement.\nEND" | ./wp_post_draft.sh --auto

echo ""
echo "📋 VÉRIFICATION CRITIQUE :"
echo ""
echo "1. **Allez dans WordPress Admin → Posts**"
echo "2. **Cherchez 'Test Brouillon Stable'**"
echo "3. **VÉRIFIEZ LE STATUT :**"
echo "   - ✅ Si 'Draft' → Le script fonctionne correctement"
echo "   - ❌ Si 'Published' → Il y a un problème côté WordPress"
echo ""
echo "🚨 **Si le post est publié au lieu d'être en brouillon :**"
echo ""
echo "📍 **Causes possibles :**"
echo "• Plugin WordPress qui auto-publie les drafts"
echo "• WPCode snippet qui change le statut"
echo "• Paramètre WordPress mal configuré"
echo "• Conflit avec d'autres plugins"
echo ""
echo "🔧 **Actions à faire :**"
echo "1. Vérifier les plugins actifs (désactiver temporairement)"
echo "2. Vérifier WPCode snippets actifs"
echo "3. Checker Settings → Writing → Default post status"
echo "4. Regarder les hooks WordPress qui modifient post_status"