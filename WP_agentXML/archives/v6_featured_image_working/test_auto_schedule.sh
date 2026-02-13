#!/bin/bash

# Test Auto-Schedule Posts at 14:00 Weekdays
echo "=== Testing Auto-Schedule Posts at 14:00 Weekdays ==="

cd "$(dirname "$0")/.."

echo ""
echo "🔧 Setup Required:"
echo "1. Install WPCode plugin in WordPress"
echo "2. Add wpcode_schedule_posts.php as new PHP snippet"
echo "3. ACTIVATE the snippet"
echo ""
echo "Creating test post that should be auto-scheduled..."

echo -e "Post Auto-Programmé Test V2\npost-auto-programme-v2\nTest de programmation automatique V2\nhttps://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=400\nCe post devrait être **automatiquement programmé** pour le prochain jour ouvrable à 14h00.\n\n## Comment ça fonctionne V2\n\n- Détection automatique du prochain créneau disponible\n- Évite les weekends (samedi/dimanche)\n- Programme à 14h00 précise\n- Compatible avec XML-RPC via custom field \`auto_schedule\`\n\n### Vérification\n\nAprès création :\n1. Allez dans WordPress Admin → Posts\n2. Le post devrait avoir le statut **\"Scheduled\"**\n3. La date/heure devrait être le prochain jour ouvrable à 14h00\n\n**Note**: Le script ajoute maintenant un custom field \`auto_schedule=1\` qui déclenche la programmation automatique.\n\nEND" | ./wp_post_draft.sh --auto

echo ""
echo "✅ Post created! Now check WordPress admin:"
echo ""
echo "📅 Expected behavior:"
echo "- Post status should be 'Scheduled' (not Draft)"
echo "- Scheduled time should be next weekday at 14:00 (2:00 PM)"
echo "- No weekends should be selected"
echo ""
echo "🔍 Verification steps:"
echo "1. Go to WordPress Admin → Posts"
echo "2. Look for 'Post Auto-Programmé Test'"
echo "3. Check that status shows 'Scheduled'"
echo "4. Verify the scheduled date/time"
echo ""
echo "💡 If not working:"
echo "- Make sure WPCode plugin is installed and activated"
echo "- Verify the wpcode_schedule_posts.php snippet is active"
echo "- Check WordPress error logs for any issues"