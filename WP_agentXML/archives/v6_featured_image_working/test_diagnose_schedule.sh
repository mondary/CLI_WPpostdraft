#!/bin/bash

# Diagnostic Script for Auto-Schedule Feature
echo "=== Diagnostic: Auto-Schedule Feature ==="

cd "$(dirname "$0")/.."

echo ""
echo "📋 Checking WordPress post status..."

# Check if we can see the last post created
echo "1. Checking last post created via curl..."
curl -s "https://mondary.design/wp-json/wp/v2/posts?per_page=1" | head -200

echo ""
echo ""
echo "2. Checking if WPCode plugin is responding..."

# Create a minimal test post to trigger the auto-schedule
echo ""
echo "Creating minimal test post..."

echo -e "Test Schedule Diagnostic\ntest-schedule-diagnostic\nDiagnostic minimal\nhttps://picsum.photos/400/200\nTest minimal pour diagnostic.\nEND" | ./wp_post_draft.sh --auto

echo ""
echo "📋 Instructions de vérification:"
echo ""
echo "1. **Allez dans WordPress Admin → Posts**"
echo "2. **Cherchez les posts:**"
echo "   - 'Post Auto-Programmé Test V2' (ID: 39301)"
echo "   - 'Test Schedule Diagnostic' (nouveau)"
echo ""
echo "3. **Vérifiez le statut:**"
echo "   - ✅ Si 'Scheduled' → Auto-scheduling fonctionne"
echo "   - ❌ Si 'Draft' → WPCode snippet pas actif"
echo ""
echo "4. **Si le problème persiste:**"
echo "   - Vérifiez que WPCode plugin est installé ET activé"
echo "   - Vérifiez que le snippet wpcode_schedule_posts.php est ajouté ET activé"
echo "   - Regardez les logs WordPress pour erreurs PHP"
echo ""
echo "5. **Debug avancé:**"
echo "   - Éditez manuellement un post et sauvegardez"
echo "   - Si ça programme automatiquement → le script XML-RPC a un problème"
echo "   - Si ça ne programme pas → le WPCode a un problème"