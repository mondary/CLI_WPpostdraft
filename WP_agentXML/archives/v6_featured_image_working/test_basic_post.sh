#!/bin/bash

# Test création de post basique (sans auto-schedule)
echo "=== Test Création Post Basique ==="

cd "$(dirname "$0")/.."

echo ""
echo "🔍 Test de création d'un simple brouillon..."
echo ""

# Test le plus simple possible
echo -e "Test Post Simple\ntest-post-simple\nTest simple\n\nContenu de test simple.\n\nCeci est juste un test basique.\nEND" | ./wp_post_draft.sh --auto

echo ""
echo "📋 Vérification :"
echo "1. Allez dans WordPress Admin → Posts"
echo "2. Cherchez 'Test Post Simple'"
echo "3. Vérifiez qu'il existe en statut 'Draft'"
echo ""
echo "💡 Si aucun post n'apparaît :"
echo "- Problème avec XML-RPC ou authentification"
echo "- Vérifiez les logs d'erreur du script ci-dessus"
echo "- Testez la connectivité : ./tests/test_diagnose_xmlrpc.sh"