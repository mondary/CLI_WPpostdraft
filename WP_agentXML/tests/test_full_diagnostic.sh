#!/bin/bash

# Diagnostic Complet - Pourquoi pas de brouillon créé
echo "=== DIAGNOSTIC COMPLET : Création de Posts ==="

cd "$(dirname "$0")/.."

echo ""
echo "🔍 Étape 1: Vérification de la configuration..."

# Vérifier si le fichier de config existe
if [ -f "mondary.conf" ]; then
    echo "✅ Fichier mondary.conf trouvé"
    source mondary.conf 2>/dev/null
    if [ -n "$WP_USERNAME" ] && [ -n "$WP_PASSWORD" ]; then
        echo "✅ Identifiants trouvés dans la configuration"
    else
        echo "❌ Identifiants manquants dans mondary.conf"
    fi
else
    echo "❌ Fichier mondary.conf introuvable"
fi

echo ""
echo "🔍 Étape 2: Test de connectivité XML-RPC..."

# Test basique de connectivité
curl_result=$(curl -s -o /dev/null -w "%{http_code}" "https://mondary.design/xmlrpc.php")
echo "Code HTTP XML-RPC: $curl_result"

if [ "$curl_result" = "405" ] || [ "$curl_result" = "200" ]; then
    echo "✅ XML-RPC endpoint accessible"
else
    echo "❌ Problème avec XML-RPC endpoint"
fi

echo ""
echo "🔍 Étape 3: Test d'authentification XML-RPC..."

if [ -n "$WP_USERNAME" ] && [ -n "$WP_PASSWORD" ]; then
    # Test d'auth avec listMethods
    auth_test="<?xml version=\"1.0\"?>
<methodCall>
    <methodName>system.listMethods</methodName>
    <params>
        <param><value><string>1</string></value></param>
        <param><value><string>$WP_USERNAME</string></value></param>
        <param><value><string>$WP_PASSWORD</string></value></param>
    </params>
</methodCall>"
    
    auth_response=$(curl -s -X POST \
        -H "Content-Type: text/xml" \
        -H "User-Agent: WordPress XML-RPC Test" \
        --max-time 10 \
        -d "$auth_test" \
        "https://mondary.design/xmlrpc.php")
    
    if echo "$auth_response" | grep -q "wp.newPost"; then
        echo "✅ Authentification réussie"
        echo "✅ Méthode wp.newPost disponible"
    elif echo "$auth_response" | grep -q "faultCode"; then
        echo "❌ Échec d'authentification"
        fault_string=$(echo "$auth_response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        echo "Erreur: $fault_string"
    else
        echo "❌ Réponse inattendue"
        echo "Réponse: ${auth_response:0:200}..."
    fi
else
    echo "❌ Pas d'identifiants pour tester l'authentification"
fi

echo ""
echo "🔍 Étape 4: Test de création de post minimal..."

# Test de création avec le script réel
echo "Test de création avec le script principal..."
echo -e "Test Diagnostic Minimal\ntest-diagnostic-minimal\nTest\n\nTest minimal.\nEND" | timeout 30 ./wp_post_draft.sh --auto 2>&1 | head -20

echo ""
echo "📋 RÉSUMÉ DU DIAGNOSTIC:"
echo ""
echo "1. Si 'Code HTTP XML-RPC: 405' → XML-RPC accessible ✅"
echo "2. Si 'Authentification réussie' → Identifiants OK ✅"
echo "3. Si 'Draft post created successfully!' → Script fonctionne ✅"
echo ""
echo "🔧 Solutions possibles si problème:"
echo "• XML-RPC désactivé → Activer dans WordPress Settings"
echo "• Mauvais identifiants → Vérifier mondary.conf"
echo "• Plugin de sécurité → Désactiver temporairement"
echo "• Script défaillant → Utiliser une version archivée"