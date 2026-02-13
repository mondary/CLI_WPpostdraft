#!/bin/bash

# Test Header Formatting Fix
echo "=== Testing Header Formatting Fix ==="

# Test with headers to verify the ## are properly converted
./wp_post_draft.sh --auto << EOF
Test Headers Fix
test-headers-fix
https://github.com/Owloops/updo/raw/main/images/demo.png
Article de test avec **headers** correctement formatés.

## Test de la fonctionnalité

Cette section devrait être un header H2 proper, pas du texte avec ##.

### Vérification

Et ceci devrait être un header H3.

#### Sous-section importante

Un header H4 pour tester.

## Résultats attendus

- Headers convertis en balises HTML appropriées
- Plus de ## visibles dans l'article final
- Structure hiérarchique correcte

---

**Succès** si les headers apparaissent comme vrais titres dans WordPress !

END
EOF

echo ""
echo "Header formatting fix test completed!"
echo ""
echo "Check the post - headers should now appear as proper H2, H3, H4 titles"
echo "No more ## visible in the content!"