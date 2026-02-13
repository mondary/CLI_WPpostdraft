#!/bin/bash

# Test Schedule Option
echo "=== Test Draft vs Scheduled Options ==="

cd "$(dirname "$0")/.."

echo ""
echo "🎯 Testing the new --schedule option:"
echo ""

echo "📝 Test 1: Creating DRAFT post (default behavior)..."
echo "Command: ./wp_post_draft.sh --auto"
echo ""

# Create a draft post using a simple echo pipe to avoid heredoc confusion
echo "Test Draft Post
test-draft-post-option
Test draft mode
https://picsum.photos/600/300
Ce post sera créé en **brouillon** avec la date d'aujourd'hui.

## Comportement par défaut

- Status: Draft
- Date: Aujourd'hui
- Auto-schedule: Désactivé

END" | ./wp_post_draft.sh --auto

echo ""
echo "📅 Test 2: Creating SCHEDULED post (with --schedule option)..."
echo "Command: ./wp_post_draft.sh --auto --schedule"
echo ""

# Create a scheduled post
echo "Test Scheduled Post
test-scheduled-post-option
Test schedule mode
https://picsum.photos/700/350
Ce post sera **programmé automatiquement** pour le futur.

## Mode Programmé

- Status: Scheduled
- Date: Prochain jour ouvrable à 14h00
- Auto-schedule: Activé

### Vérification

1. Allez dans WordPress Admin → Posts
2. Vérifiez que ce post a le statut 'Scheduled'
3. La date devrait être dans le futur

END" | ./wp_post_draft.sh --auto --schedule

echo ""
echo "✅ Tests terminés !"
echo ""
echo "📋 Vérification attendue dans WordPress Admin:"
echo ""
echo "1. **Test Draft Post**:"
echo "   - Status: Draft"
echo "   - Date: Aujourd'hui"
echo ""
echo "2. **Test Scheduled Post**:"
echo "   - Status: Scheduled"
echo "   - Date: Prochain jour ouvrable à 14h00"
echo ""
echo "💡 **Important**: Pour que la programmation fonctionne, assurez-vous que:"
echo "   - Le WPCode snippet wpcode_schedule_posts_fixed.php est activé"
echo "   - Il a remplacé l'ancien snippet de programmation"
echo ""
echo "🔧 **Usage des nouvelles options:**"
echo "   ./wp_post_draft.sh --auto           # Brouillon normal"
echo "   ./wp_post_draft.sh --auto --schedule # Post programmé"