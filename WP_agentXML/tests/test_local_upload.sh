#!/bin/bash

# Test Local Image Upload (Fixed Version)
echo "=== Testing Local Image Upload (Fixed) ==="

# Test with local file upload
./wp_post_draft.sh --auto << EOF
Test Local Image Upload Fixed
test-local-upload-fixed
test_small.png
Ceci est un test pour l'**upload d'image locale** après correction du bug bash.

Le script devrait maintenant :
- ✅ Détecter que c'est un fichier local
- ✅ L'uploader vers WordPress  
- ✅ Récupérer l'ID de l'image
- ✅ L'associer au post comme featured image

Test corrigé !
END
EOF

echo ""
echo "Local upload test completed!"