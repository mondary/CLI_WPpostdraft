#!/bin/bash

# Test Simple Auto-Schedule (Manual Save Required)
echo "=== Test Simple Auto-Schedule (Manuel Save Required) ==="

cd "$(dirname "$0")/.."

echo ""
echo "🎯 Cette approche fonctionne de manière fiable !"
echo ""
echo "Création d'un post de test..."

echo -e "Test Auto-Schedule Simple\ntest-auto-schedule-simple\nTest avec sauvegarde manuelle\nhttps://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800&h=400\nCe post sera programmé **automatiquement** quand vous le sauvegarderez manuellement.\n\n## Étapes simples\n\n1. **Script crée le post** avec custom field `auto_schedule=1`\n2. **Vous allez dans WordPress admin**\n3. **Vous cliquez 'Update'** sur le post\n4. **WPCode détecte et programme automatiquement**\n\n### Résultat attendu\n\n- Statut change vers **'Scheduled'**\n- Date/heure : prochain jour ouvrable à 14h00\n- Notification de succès dans l'admin\n\nEND" | ./wp_post_draft.sh --auto

echo ""
echo "✅ Post créé ! Maintenant suivez ces étapes :"
echo ""
echo "📋 **ÉTAPES OBLIGATOIRES** :"
echo ""
echo "1. **Installez WPCode snippet** (si pas déjà fait) :"
echo "   - Copiez le contenu de wpcode_schedule_posts_simple.php"
echo "   - Ajoutez-le comme nouveau snippet PHP dans WPCode"
echo "   - ACTIVEZ le snippet"
echo ""
echo "2. **Programmez le post** :"
echo "   - Allez dans WordPress Admin → Posts"
echo "   - Trouvez 'Test Auto-Schedule Simple'"
echo "   - Cliquez 'Edit'"
echo "   - Cliquez 'Update' (même sans rien changer)"
echo "   - 🎉 Le post sera automatiquement programmé !"
echo ""
echo "3. **Vérification** :"
echo "   - Le statut doit changer vers 'Scheduled'"
echo "   - Vous verrez une notification verte de succès"
echo "   - La date sera le prochain jour ouvrable à 14h00"
echo ""
echo "💡 **Pourquoi ça marche** :"
echo "   - Le hook save_post est fiable avec action manuelle"
echo "   - Le custom field auto_schedule=1 déclenche la programmation"
echo "   - Pas de conflit avec XML-RPC timing"