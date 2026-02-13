#!/bin/bash

# Test Featured Image Upload Functionality
# This script tests the new featured image upload capabilities

echo "=== Testing Featured Image Upload Functionality ==="
echo ""

# Create a small test image file first (placeholder)
echo "Creating test image file..."

# Create a simple 1x1 pixel PNG image using base64
test_image_data="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
echo "$test_image_data" | base64 -d > test_image.png

echo "Created test_image.png (1x1 pixel)"

# Test with local file upload
test_content_local="Test Featured Image Upload (Local File)
test-featured-image-local
test_image.png

Ceci est un test pour l'upload d'une **image locale** comme image à la une.

Le script devrait :
- Détecter que c'est un fichier local
- L'uploader vers WordPress
- Récupérer l'ID de l'image
- L'associer au post comme featured image

---

Test réussi si l'image apparaît comme image à la une du post.

END"

echo "Content to test (local file):"
echo "============================="
echo "$test_content_local"
echo ""
echo "============================="
echo ""

# Test the local image upload
echo "Testing local image upload with wp_post_draft.sh --auto:"
echo "$test_content_local" | ./wp_post_draft.sh --auto

echo ""

# Test with URL (existing behavior)
test_content_url="Test Featured Image Upload (URL)
test-featured-image-url

https://mondary.design/wp-content/uploads/2025/08/VibeNotes_2.avif

Ceci est un test pour l'utilisation d'une **URL d'image** comme image à la une.

Le script devrait :
- Détecter que c'est une URL
- L'utiliser comme avant (pas d'upload)
- L'associer au post

---

Test de compatibilité avec l'ancien comportement.

END"

echo "Content to test (URL):"
echo "====================="
echo "$test_content_url"
echo ""
echo "====================="
echo ""

# Test the URL behavior
echo "Testing URL behavior with wp_post_draft.sh --auto:"
echo "$test_content_url" | ./wp_post_draft.sh --auto

# Cleanup
echo ""
echo "Cleaning up test files..."
rm -f test_image.png

echo ""
echo "Featured image upload tests completed!"