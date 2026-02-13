# Guide d'Utilisation Simple - Featured Images

## ✅ **Étapes pour Utiliser les Featured Images**

### 1. **Créer un Post avec Featured Image**
```bash
./wp_post_draft.sh --auto
```
- Entrez votre titre, slug, excerpt
- **Pour Featured Image** : Entrez une URL d'image (ex: https://example.com/image.jpg)
- Le script affichera un ⚠️ message vous rappelant la prochaine étape

### 2. **Installer WPCode (Une seule fois)**
- Allez dans **WordPress Admin → Plugins → Add New**
- Recherchez "**WPCode**" et installez-le
- **Activez** le plugin

### 3. **Ajouter le Snippet PHP (Une seule fois)**
- Allez dans **WordPress Admin → WPCode → Code Snippets**
- Cliquez **"Add Snippet"**
- Choisissez **"Add Your Custom Code (New Snippet)"**
- Sélectionnez **"PHP Snippet"**
- Copiez **tout le contenu** de `wpcode_featured_image.php`
- Titre : "Featured Image from URL"
- **ACTIVEZ** le snippet (très important !)

### 4. **Activer la Featured Image**
Après avoir créé un post avec le script :
- Allez dans **WordPress Admin → Posts**
- Cliquez sur **"Edit"** pour le post créé
- Cliquez **"Update"** (même sans faire de changement)
- ✅ **La featured image apparaît automatiquement !**

## 🔧 **Comment ça fonctionne**

1. **Script** → Crée le post avec custom field `featured_image_url`
2. **WPCode** → Détecte le custom field quand vous sauvegardez
3. **WordPress** → Télécharge l'image et la définit comme featured image
4. **Résultat** → Featured image visible partout (admin, front-end, social media)

## ❌ **Erreurs Communes à Éviter**

### Featured Image ne s'affiche pas ?
- ✅ Vérifiez que **WPCode plugin** est installé ET activé
- ✅ Vérifiez que le **snippet PHP** est ajouté ET activé
- ✅ **Sauvegardez le post** dans WordPress admin après création
- ✅ Utilisez une **URL d'image accessible** (testez l'URL dans le navigateur)

### Le script dit "Featured Image URL set" mais rien ne se passe ?
- ⚠️ C'est **normal** ! Le script fait seulement la première partie
- 🔧 Vous **devez** aller dans WordPress admin et sauvegarder le post
- 💡 Le traitement se fait côté WordPress, pas côté script

## 🎯 **Vérification Rapide**

Si vous avez un doute, créez ce test simple :
```bash
./wp_post_draft.sh --auto << 'EOF'
Test Featured Image
test-featured-image
Ceci est un test
https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800&h=400
Test de featured image simple.
END
EOF
```

Puis :
1. Allez dans WordPress admin
2. Éditez le post "Test Featured Image"  
3. Cliquez "Update"
4. L'image doit apparaître dans la sidebar droite

---

**💡 Une fois configuré, le système fonctionne pour tous vos futurs posts !**