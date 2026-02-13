# Guide d'Installation: Featured Image depuis URL avec WPCode

## Étape 1: Installation WPCode
1. Allez dans votre admin WordPress
2. Extensions → Ajouter → Rechercher "WPCode"
3. Installez et activez le plugin "WPCode"

## Étape 2: Ajouter la fonction PHP
1. Allez dans WPCode → Code Snippets
2. Cliquez "Add Snippet"
3. Choisissez "Add Your Custom Code (New Snippet)"
4. Sélectionnez "PHP Snippet"
5. Titre: "Featured Image from URL"
6. Copiez-collez le code de `wpcode_featured_image.php`
7. Activez le snippet

## Étape 3: Tester le script modifié
```bash
./wp_post_draft.sh --auto
```

## Comment ça fonctionne:
1. **Script Shell**: Crée le post avec custom field `featured_image_url`
2. **WPCode Function**: Détecte automatiquement le custom field
3. **WordPress**: Télécharge l'image et la définit comme featured image
4. **Résultat**: Image à la une automatiquement assignée

## Avantages:
- ✅ Fonctionne avec n'importe quelle URL d'image
- ✅ Télécharge et stocke l'image dans la médiathèque
- ✅ Génère automatiquement les différentes tailles
- ✅ Gère les erreurs de téléchargement
- ✅ Compatible avec tous les thèmes WordPress

## Test:
1. Créez un post avec une URL d'image
2. L'image devrait automatiquement apparaître comme featured image
3. Vérifiez dans Médias → Médiathèque que l'image a été importée

## Debug:
Si ça ne fonctionne pas, vérifiez:
1. WPCode snippet est activé
2. Logs WordPress (Outils → Santé du site → Info → Logs)
3. Permissions d'écriture du dossier uploads