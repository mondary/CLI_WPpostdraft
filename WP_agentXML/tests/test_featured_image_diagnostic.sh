#!/bin/bash

# Simple Featured Image Test
echo "=== Featured Image Diagnostic ==="

cd "$(dirname "$0")/.."

echo "1. Testing image URL accessibility..."
echo "URL: https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&h=630&fit=crop&q=80"

# Test URL
response=$(curl -s -o /dev/null -w "%{http_code}" "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&h=630&fit=crop&q=80")
echo "HTTP Response: $response"

if [ "$response" = "200" ]; then
    echo "✅ Image URL is accessible"
else
    echo "❌ Image URL is not accessible"
    exit 1
fi

echo ""
echo "2. Creating test post with featured image..."

./wp_post_draft.sh --auto << 'EOF'
Test Featured Image Simple
test-featured-image-simple
Test simple pour vérifier que la featured image fonctionne correctement.
https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&h=630&fit=crop&q=80
# Test Featured Image Simple

Ceci est un **test simple** pour vérifier la fonctionnalité des images à la une.

## Vérifications

- ✅ URL d'image accessible
- ✅ Custom field `featured_image_url` créé
- ✅ WPCode snippet actif

## Image de test

![Test Image](https://images.unsplash.com/photo-1517077304055-6e89abbf09b0?w=600&h=300&fit=crop)

---

**Résultat attendu** : Image à la une visible dans WordPress admin.

END
EOF

echo ""
echo "✅ Test completed!"
echo ""
echo "🔍 Next steps:"
echo "1. Go to WordPress admin"
echo "2. Find the post 'Test Featured Image Simple'"
echo "3. Check if featured image appears"
echo "4. If not, verify WPCode snippet is active"