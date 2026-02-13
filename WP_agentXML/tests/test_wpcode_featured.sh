#!/bin/bash

# Test WPCode Featured Image Solution
echo "=== Testing WPCode Featured Image Solution ==="

# Test with GitHub image URL
./wp_post_draft.sh --auto << EOF
Test WPCode Featured Image
test-wpcode-featured-image
https://github.com/Owloops/updo/raw/main/images/demo.png
Ceci est un test avec la **solution WPCode** pour les images à la une.

Le script devrait :
- ✅ Créer le post avec un custom field 'featured_image_url'
- ✅ WPCode détecte automatiquement le custom field
- ✅ Télécharge l'image dans la médiathèque
- ✅ L'assigne comme featured image

Cette solution est plus robuste car elle utilise les fonctions natives de WordPress.

---

**Instructions :**
1. Installez WPCode plugin
2. Ajoutez le snippet PHP fourni
3. Activez le snippet
4. Testez ce script

END
EOF

echo ""
echo "WPCode featured image test completed!"
echo ""
echo "IMPORTANT:"
echo "1. Assurez-vous que WPCode est installé et activé"
echo "2. Ajoutez le snippet PHP de wpcode_featured_image.php"
echo "3. Activez le snippet dans WPCode"
echo "4. L'image devrait automatiquement apparaître comme featured image"