#!/bin/bash

# Test Complete Blog Post with Featured Image
echo "=== Testing Complete Blog Post with All Features ==="

cd "$(dirname "$0")"

echo "Testing featured image URL accessibility..."
curl -s -I "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&h=630&fit=crop&q=80" | head -1

echo ""
echo "Creating complete blog post..."

./wp_post_draft.sh --auto << 'EOF'
Guide Complet : Automatiser WordPress en 2025
guide-automatiser-wordpress-2025
Découvrez les meilleures techniques pour automatiser votre blog WordPress et booster votre productivité. Tutoriel complet avec exemples concrets. 🚀 #WordPress #Automation
https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&h=630&fit=crop&q=80
# Guide Complet : Automatiser WordPress en 2025

L'**automatisation WordPress** révolutionne la façon dont nous gérons nos blogs et sites web.

## 🎯 Pourquoi Automatiser ?

### Avantages Principaux

- **Productivité** : Gain de temps considérable
- **Consistance** : Qualité uniforme du contenu
- **Scalabilité** : Gestion de multiples sites
- **Efficacité** : Moins d'erreurs manuelles

## 🛠️ Outils Essentiels

### Scripts d'Automatisation

```bash
# Publication automatique
./wp_post_draft.sh --auto
```

### Intégration Social Media

L'automatisation inclut le **partage social automatique** :

![Social Media Integration](https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=600&h=300&fit=crop)

- Synchronisation excerpt → message
- Featured image → attachment
- Cross-platform publishing

---

## 📋 Guide Pratique

### Configuration de Base

```php
// Activer XML-RPC
add_filter('xmlrpc_enabled', '__return_true');
```

### Workflow Automatisé

1. **Rédaction** en Markdown
2. **Formatage** automatique
3. **Publication** programmée
4. **Partage** social automatique

## 💡 Bonnes Pratiques

- ✅ Tester avant déploiement
- ✅ Sauvegarder régulièrement
- ✅ Monitorer les performances
- ✅ Optimiser le SEO

## 🚀 Conclusion

L'automatisation WordPress n'est plus optionnelle. C'est un **avantage concurrentiel** essentiel pour tout créateur de contenu moderne.

**Prochaine étape** : Implémentez ces techniques et mesurez l'impact sur votre productivité !

END
EOF

echo ""
echo "✅ Complete blog post created!"
echo ""
echo "🔍 Verification steps:"
echo "1. Check WordPress admin for the new post"
echo "2. Verify featured image appears in sidebar"
echo "3. Confirm excerpt is set correctly"
echo "4. Test Jetpack Social integration"
echo ""
echo "📊 Expected results:"
echo "- Title: 'Guide Complet : Automatiser WordPress en 2025'"
echo "- Featured Image: Computer/automation themed image"
echo "- Excerpt: Used as social message"
echo "- Content: Rich formatting with headers, code blocks, images"