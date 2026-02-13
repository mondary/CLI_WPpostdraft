#!/bin/bash

# Test Rich Text Formatting Features
# This script tests all formatting options available in wp_post_draft.sh

echo "=== Testing Rich Text Formatting ==="
echo ""

# Create test content with all formatting features
test_content="Test Article avec Formatage
test-formatage-article
https://mondary.design/wp-content/uploads/2025/08/test-image.jpg

Ceci est un **paragraphe en gras** avec du texte normal et de l'*italique*.

## Fonctionnalités principales :

- 🕹 **Compatibilité étendue** : support natif pour Steam, Lutris, Epic Games Store
- ⚡ **Performances optimisées** : CPU scheduler avancé, drivers préinstallés  
- 🔒 *Sécurité renforcée* : SELinux, Secure Boot, LUKS avec TPM
- 📱 Flexibilité matérielle : fonctionne sur PC de bureau et portables

Voici un exemple de \`code inline\` dans une phrase normale.

---

Pour les commandes système, on peut utiliser des blocs de code :

\`\`\`bash
sudo dnf update
systemctl status steam
\`\`\`

===

Le système intègre aussi des environnements modernes comme **KDE Plasma** et *GNOME*, permettant d'exécuter facilement des __conteneurs Linux__ pour des usages avancés.

Finalement, un OS qui réunit _performance_, **polyvalence** et \`sécurité\`.

END"

echo "Content to test:"
echo "=================="
echo "$test_content"
echo ""
echo "=================="
echo ""

# Test the formatting by sending it to the script
echo "Testing with wp_post_draft.sh --auto:"
echo "$test_content" | ./wp_post_draft.sh --auto

echo ""
echo "Test completed!"