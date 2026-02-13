#!/bin/bash

# Test Inline Image Functionality
# This script tests the new inline image features

echo "=== Testing Inline Image Functionality ==="
echo ""

# Create test content with various image formats
test_content="Test Article avec Images Inline
test-images-inline-article
https://mondary.design/wp-content/uploads/2025/08/featured-image.jpg

Voici un article avec différents types d'images.

Premier paragraphe avec du texte normal.

![Image avec texte alternatif](https://mondary.design/wp-content/uploads/2025/08/VibeNotes_2.avif)

Deuxième paragraphe après l'image.

https://mondary.design/wp-content/uploads/2025/08/bazzite-1024x527.png

Un autre paragraphe avec une image **inline dans le texte** ![petite image](https://mondary.design/wp-content/uploads/2025/08/small.jpg) et du texte qui continue.

---

Section avec séparateur et code :

\`\`\`bash
echo \"Test avec image\"
\`\`\`

![Dernière image](https://mondary.design/wp-content/uploads/2025/08/final.webp)

Conclusion de l'article.

END"

echo "Content to test:"
echo "=================="
echo "$test_content"
echo ""
echo "=================="
echo ""

# Test the inline images functionality
echo "Testing inline images with wp_post_draft.sh --auto:"
echo "$test_content" | ./wp_post_draft.sh --auto

echo ""
echo "Inline image test completed!"