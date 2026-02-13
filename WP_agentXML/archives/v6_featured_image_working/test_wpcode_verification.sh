#!/bin/bash

# Test WPCode Featured Image - Verification Test
echo "=== Testing WPCode Featured Image After Installation ==="

# Test with a different image to verify WPCode is working
./wp_post_draft.sh --auto << EOF
Verification Test WPCode Featured Image
test-verification-wpcode-featured
https://github.com/Owloops/updo/raw/main/images/demo.png
Ceci est un **test de vérification** après installation du code WPCode.

## Test de la fonctionnalité

Si WPCode fonctionne correctement, cette image devrait :
- ✅ Être automatiquement téléchargée dans la médiathèque
- ✅ Apparaître comme image à la une du post
- ✅ Être visible dans l'éditeur WordPress

## Vérification

Pour vérifier que ça fonctionne :
1. Allez dans WordPress Admin → Articles
2. Ouvrez ce post en édition
3. Vérifiez que l'image à la une est bien définie
4. Allez dans Médias → Médiathèque
5. Vérifiez que l'image a été importée

---

**Image de test :** demo.png du repository Owloops/updo

END
EOF

echo ""
echo "🔍 Verification test completed!"
echo ""
echo "📋 Next steps:"
echo "1. Go to WordPress Admin → Posts"
echo "2. Open the created post"
echo "3. Check if featured image is set"
echo "4. Go to Media Library to verify image was downloaded"
echo ""
echo "If featured image appears → ✅ WPCode is working!"
echo "If no featured image → ❌ Check WPCode snippet activation"