#!/bin/bash

# Test Draft vs Scheduled Posts
echo "=== Test Draft vs Scheduled Posts ==="

cd "$(dirname "$0")/.."

echo ""
echo "🎯 Testing two scenarios:"
echo "1. Normal draft (stays as draft with today's date)"
echo "2. Scheduled post (gets future date via auto-scheduling)"
echo ""

echo "📝 Creating DRAFT post (current behavior)..."
echo -e "Test Draft Post\ntest-draft-post\nTest draft behavior\nhttps://picsum.photos/600/300\nCe post reste en **brouillon** avec la date d'aujourd'hui.\n\nC'est le comportement normal pour les brouillons.\nEND" | ./wp_post_draft.sh --auto

echo ""
echo "📅 Want to create a SCHEDULED post instead?"
echo ""
echo "💡 Pour programmer un post, vous pouvez:"
echo "1. Aller dans WordPress Admin → Posts"
echo "2. Modifier le post"
echo "3. Changer la date de publication vers le futur"
echo "4. Cliquer 'Schedule'"
echo ""
echo "🔧 Ou je peux modifier le script pour ajouter une option --schedule"
echo ""
echo "📋 Vérification:"
echo "- Le post 'Test Draft Post' devrait être en statut 'Draft'"
echo "- Il devrait avoir la date/heure d'aujourd'hui"
echo "- C'est le comportement normal et correct!"