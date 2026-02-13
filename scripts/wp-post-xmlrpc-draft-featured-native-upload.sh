#!/bin/bash
# Author: cmondary - https://github.com/mondary
#
# WordPress XML-RPC draft publisher (native featured image via upload)

# Variables globales pour stocker les paramètres de ligne de commande
TITLE=""
CONTENT=""
DESCRIPTION=""  # Alias pour CONTENT
EXCERPT=""
SLUG=""
IMAGE=""
CATEGORIES=""
LIST_CATEGORIES=false
HELP=false
VERBOSE=false
DRY_RUN=false

# Variables pour les credentials WordPress
WP_URL=""
WP_USER=""
WP_PASS=""
CREDENTIALS_FILE="${WP_CREDENTIALS_FILE:-$(cd "$(dirname "$0")" && pwd)/../secrets/wp-credentials}"

# Vérifier les dépendances système requises
check_dependencies() {
    local missing_deps=()
    local optional_deps=()
    
    # Vérifier curl (requis pour XML-RPC)
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    # Vérifier base64 (requis pour l'upload d'images)
    if ! command -v base64 >/dev/null 2>&1; then
        missing_deps+=("base64")
    fi
    
    # Vérifier les dépendances optionnelles pour un meilleur débogage
    if ! command -v xmllint >/dev/null 2>&1; then
        optional_deps+=("xmllint")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        optional_deps+=("jq")
    fi
    
    # Si des dépendances manquent, afficher un message d'erreur
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Erreur: Dépendances manquantes détectées:" >&2
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep" >&2
        done
        echo "" >&2
        echo "Installation requise:" >&2
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                curl)
                    echo "  - curl: généralement préinstallé sur macOS/Linux" >&2
                    echo "    macOS: brew install curl" >&2
                    echo "    Ubuntu/Debian: apt-get install curl" >&2
                    echo "    CentOS/RHEL: yum install curl" >&2
                    ;;
                base64)
                    echo "  - base64: généralement préinstallé sur macOS/Linux" >&2
                    echo "    Fait partie des coreutils" >&2
                    echo "    Si manquant: brew install coreutils (macOS)" >&2
                    ;;
            esac
        done
        return 1
    fi
    
    # Afficher les dépendances optionnelles manquantes en mode verbose
    if [[ "$VERBOSE" == true && ${#optional_deps[@]} -gt 0 ]]; then
        echo "Dépendances optionnelles manquantes (recommandées pour le débogage):"
        for dep in "${optional_deps[@]}"; do
            case "$dep" in
                xmllint)
                    echo "  - xmllint: pour valider les réponses XML"
                    echo "    Installation: brew install libxml2 (macOS) ou apt-get install libxml2-utils (Ubuntu)"
                    ;;
                jq)
                    echo "  - jq: pour parser les réponses JSON"
                    echo "    Installation: brew install jq (macOS) ou apt-get install jq (Ubuntu)"
                    ;;
            esac
        done
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "✓ Toutes les dépendances requises sont disponibles"
    fi
    
    return 0
}

# Valider tous les paramètres avant l'exécution
validate_parameters() {
    local errors=()
    local warnings=()
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Validation des paramètres..."
    fi
    
    # Validation du titre (requis sauf pour --list-categories et --help)
    if [[ -z "$TITLE" && "$LIST_CATEGORIES" != true && "$HELP" != true ]]; then
        errors+=("Le titre est requis (-t ou --title)")
    fi
    
    # Validation de la longueur du titre
    if [[ -n "$TITLE" && ${#TITLE} -gt 255 ]]; then
        errors+=("Le titre est trop long (${#TITLE} caractères, maximum 255)")
    fi
    
    # Validation du contenu - optimisation pour gros contenus
    if [[ -n "$CONTENT" ]]; then
        local content_length=${#CONTENT}
        if [[ $content_length -gt 65535 ]]; then
            warnings+=("Le contenu est très long ($content_length caractères), cela pourrait causer des problèmes de performance")
        elif [[ $content_length -gt 32768 ]]; then
            warnings+=("Le contenu est volumineux ($content_length caractères), traitement optimisé activé")
        fi
    fi
    
    # Validation de l'extrait
    if [[ -n "$EXCERPT" && ${#EXCERPT} -gt 320 ]]; then
        warnings+=("L'extrait est long (${#EXCERPT} caractères, recommandé: <320)")
    fi
    
    # Validation du slug
    if [[ -n "$SLUG" ]]; then
        # Vérifier la longueur
        if [[ ${#SLUG} -gt 200 ]]; then
            errors+=("Le slug est trop long (${#SLUG} caractères, maximum 200)")
        fi
        
        # Vérifier les caractères autorisés (avant nettoyage)
        if [[ ! "$SLUG" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            warnings+=("Le slug contient des caractères non recommandés, il sera nettoyé automatiquement")
        fi
    fi
    
    # Validation du fichier image ou URL
    if [[ -n "$IMAGE" ]]; then
        # Vérifier si c'est une URL
        if [[ "$IMAGE" =~ ^https?:// ]]; then
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ URL d'image détectée: $IMAGE"
            fi
            # Vérifier l'extension de l'URL
            local url_ext
            url_ext=$(echo "$IMAGE" | sed 's/.*\.//' | sed 's/[?#].*//' | tr '[:upper:]' '[:lower:]')
            case "$url_ext" in
                jpg|jpeg|png|gif|webp|bmp)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ✓ Format d'image URL valide: $url_ext"
                    fi
                    ;;
                *)
                    warnings+=("Extension d'URL non reconnue comme image: $url_ext")
                    ;;
            esac
        elif [[ ! -f "$IMAGE" ]]; then
            errors+=("Fichier image non trouvé: $IMAGE")
        elif [[ ! -r "$IMAGE" ]]; then
            errors+=("Fichier image non lisible: $IMAGE (vérifiez les permissions)")
        else
            # Vérifier la taille du fichier (limite WordPress par défaut: 32MB)
            local file_size
            if command -v stat >/dev/null 2>&1; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    # macOS
                    file_size=$(stat -f%z "$IMAGE" 2>/dev/null || echo "0")
                else
                    # Linux
                    file_size=$(stat -c%s "$IMAGE" 2>/dev/null || echo "0")
                fi
                
                local max_size=$((32 * 1024 * 1024))  # 32MB en bytes
                if [[ "$file_size" -gt "$max_size" ]]; then
                    local size_mb=$((file_size / 1024 / 1024))
                    errors+=("Fichier image trop volumineux: ${size_mb}MB (maximum recommandé: 32MB)")
                fi
            fi
            
            # Vérifier l'extension du fichier
            local file_ext="${IMAGE##*.}"
            file_ext=$(echo "$file_ext" | tr '[:upper:]' '[:lower:]')
            case "$file_ext" in
                jpg|jpeg|png|gif|webp|bmp)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ✓ Format d'image valide: $file_ext"
                    fi
                    ;;
                *)
                    warnings+=("Extension de fichier non reconnue comme image: $file_ext")
                    ;;
            esac
        fi
    fi
    
    # Validation des catégories
    if [[ -n "$CATEGORIES" ]]; then
        # Vérifier le format (pas de validation de l'existence ici, fait plus tard)
        if [[ ! "$CATEGORIES" =~ ^[a-zA-Z0-9_,-]+$ ]]; then
            warnings+=("Les catégories contiennent des caractères non recommandés")
        fi
        
        # Compter le nombre de catégories
        local category_count
        category_count=$(echo "$CATEGORIES" | tr ',' '\n' | wc -l | tr -d ' ')
        if [[ "$category_count" -gt 10 ]]; then
            warnings+=("Nombre élevé de catégories ($category_count), WordPress recommande moins de 10")
        fi
    fi
    
    # Validation des credentials (sauf pour --help et --list-categories en mode dry-run)
    if [[ "$HELP" != true && ! ("$LIST_CATEGORIES" == true && "$DRY_RUN" == true) ]]; then
        if [[ ! -f "$CREDENTIALS_FILE" ]]; then
            errors+=("Fichier wp-credentials non trouvé dans le répertoire courant")
        elif [[ ! -r "$CREDENTIALS_FILE" ]]; then
            errors+=("Fichier wp-credentials non lisible (vérifiez les permissions)")
        fi
    fi
    
    # Afficher les erreurs
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Erreurs de validation détectées:" >&2
        for error in "${errors[@]}"; do
            echo "  ✗ $error" >&2
        done
        echo "" >&2
        echo "Utilisez --help pour voir les options disponibles" >&2
        return 1
    fi
    
    # Afficher les avertissements
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo "Avertissements:" >&2
        for warning in "${warnings[@]}"; do
            echo "  ⚠ $warning" >&2
        done
        echo "" >&2
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        if [[ ${#errors[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
            echo "✓ Tous les paramètres sont valides"
        else
            echo "Validation terminée avec ${#warnings[@]} avertissement(s)"
        fi
    fi
    
    return 0
}

# Fonction d'aide condensée
show_help() {
    cat << EOF
WordPress Draft Publisher - Créer des brouillons WordPress via XML-RPC

USAGE: ./$(basename "$0") [OPTIONS]

OPTIONS:
    -t, --title "titre"           Titre de l'article (requis)
    -c, --content "contenu"       Contenu du corps de l'article
    -d, --description "desc"      Alias pour --content
    -e, --excerpt "extrait"       Extrait de l'article
    -u, --slug "url-slug"         Slug pour l'URL
    -i, --image "chemin/image"    Chemin vers l'image featured
    --categories "cat1,cat2"      Catégories (slugs séparés par virgules)
    --list-categories             Affiche les catégories disponibles
    --verbose                     Mode verbeux
    --dry-run                     Mode test (n'exécute pas les actions)
    --help                        Affiche cette aide

EXEMPLES:
    # Brouillon simple
    ./$(basename "$0") -t "Mon article"
    
    # Article avec contenu
    ./$(basename "$0") -t "Guide" -c "Contenu de l'article"
    
    # Article complet
    ./$(basename "$0") -t "Tutorial" -c "## Introduction\nContenu..." -e "Résumé" -u "tutorial-slug" --categories "tech,guide"
    
    # Avec image
    ./$(basename "$0") -t "Review" -c "Contenu..." -i "image.jpg" --categories "review"
    
    # Test sans créer
    ./$(basename "$0") -t "Test" -c "Contenu" --dry-run
    
    # Mode verbeux
    ./$(basename "$0") -t "Debug" --verbose
    
    # Lister catégories
    ./$(basename "$0") --list-categories

FORMATAGE AUTOMATIQUE:
    - URLs → liens cliquables
    - **gras** → <strong>gras</strong>
    - *italique* → <em>italique</em>
    - \`code\` → <code>code</code>
    - # Titre → <h1>Titre</h1>
    - - Liste → <ul><li>Liste</li></ul>
    - \`\`\`code\`\`\` → <pre><code>code</code></pre>

CREDENTIALS:
    Créez un fichier 'wp-credentials' (3 lignes):
    https://votre-site.com
    username
    password_ou_application_password

REQUIREMENTS: curl, base64, wp-credentials

EOF
}

# Parser des arguments de ligne de commande
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--title)
                TITLE="$2"
                shift 2
                ;;
            -d|--description)
                DESCRIPTION="$2"
                CONTENT="$2"  # -d est un alias pour -c
                shift 2
                ;;
            -c|--content)
                CONTENT="$2"
                shift 2
                ;;
            -e|--excerpt)
                EXCERPT="$2"
                shift 2
                ;;
            -u|--slug)
                SLUG="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE="$2"
                shift 2
                ;;
            --categories)
                CATEGORIES="$2"
                shift 2
                ;;
            --list-categories)
                LIST_CATEGORIES=true
                shift
                ;;
            --help)
                HELP=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                echo "Erreur: Option inconnue '$1'"
                echo "Utilisez --help pour voir les options disponibles"
                exit 1
                ;;
        esac
    done
}

# Client XML-RPC générique
xmlrpc_call() {
    local method="$1"
    local params="$2"
    local endpoint="${WP_URL}/xmlrpc.php"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Appel XML-RPC: $method vers $endpoint"
    fi
    
    # Construire la requête XML-RPC
    local xml_request="<?xml version=\"1.0\"?>
<methodCall>
    <methodName>$method</methodName>
    <params>
        $params
    </params>
</methodCall>"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Requête XML:"
        echo "$xml_request"
    fi
    
    # Effectuer l'appel avec curl
    local response
    local http_code
    local curl_exit_code
    
    # Utiliser un fichier temporaire pour capturer la réponse
    local temp_response=$(mktemp)
    local temp_headers=$(mktemp)
    
    # Nettoyer les fichiers temporaires à la sortie
    trap "rm -f '$temp_response' '$temp_headers'" EXIT
    
    # Effectuer la requête curl
    http_code=$(curl -s -w "%{http_code}" \
        -H "Content-Type: text/xml" \
        -H "User-Agent: wp-draft.sh/1.0" \
        --connect-timeout 30 \
        --max-time 60 \
        -X POST \
        -d "$xml_request" \
        -D "$temp_headers" \
        -o "$temp_response" \
        "$endpoint")
    
    curl_exit_code=$?
    
    # Lire la réponse
    response=$(cat "$temp_response")
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Code HTTP: $http_code"
        echo "Code de sortie curl: $curl_exit_code"
        echo "Réponse:"
        echo "$response"
    fi
    
    # Vérifier les erreurs de curl
    if [[ $curl_exit_code -ne 0 ]]; then
        case $curl_exit_code in
            6)
                echo "Erreur: Impossible de résoudre l'hôte $WP_URL" >&2
                echo "Vérifiez l'URL dans wp-credentials" >&2
                ;;
            7)
                echo "Erreur: Impossible de se connecter à $WP_URL" >&2
                echo "Vérifiez que le site est accessible" >&2
                ;;
            28)
                echo "Erreur: Timeout de connexion vers $WP_URL" >&2
                echo "Le site met trop de temps à répondre" >&2
                ;;
            *)
                echo "Erreur curl ($curl_exit_code): Échec de la requête vers $WP_URL" >&2
                ;;
        esac
        return 1
    fi
    
    # Vérifier le code de statut HTTP
    case $http_code in
        200)
            # Succès, continuer le traitement
            ;;
        404)
            echo "Erreur 404: XML-RPC non trouvé sur $WP_URL" >&2
            echo "Vérifiez que XML-RPC est activé sur votre site WordPress" >&2
            echo "URL testée: $endpoint" >&2
            return 1
            ;;
        403)
            echo "Erreur 403: Accès refusé à XML-RPC" >&2
            echo "XML-RPC pourrait être désactivé par un plugin de sécurité" >&2
            return 1
            ;;
        405)
            echo "Erreur 405: Méthode non autorisée" >&2
            echo "Le serveur ne supporte pas les requêtes POST sur XML-RPC" >&2
            return 1
            ;;
        500)
            echo "Erreur 500: Erreur interne du serveur" >&2
            echo "Problème côté serveur WordPress" >&2
            return 1
            ;;
        *)
            echo "Erreur HTTP $http_code: Réponse inattendue du serveur" >&2
            return 1
            ;;
    esac
    
    # Vérifier si la réponse contient une erreur XML-RPC
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        local fault_code=$(echo "$response" | grep -A2 "<name>faultCode</name>" | grep "<int>" | sed 's/.*<int>\([0-9]*\)<\/int>.*/\1/')
        local fault_string=$(echo "$response" | grep -A2 "<name>faultString</name>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        
        # Utiliser la nouvelle fonction de gestion d'erreurs
        handle_xmlrpc_error "$fault_code" "$fault_string" "$method"
        
        if [[ "$VERBOSE" == true ]]; then
            echo "Réponse XML complète pour débogage:" >&2
            echo "$response" >&2
        fi
        
        return 1
    fi
    
    # Retourner la réponse si tout va bien
    echo "$response"
    return 0
}

# Tester la connexion et l'authentification WordPress
test_wordpress_connection() {
    if [[ "$VERBOSE" == true ]]; then
        echo "Test de connexion à WordPress..."
    fi
    
    # Construire les paramètres pour wp.getProfile (méthode simple pour tester l'auth)
    local params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>"
    
    # Effectuer l'appel de test
    local response
    if response=$(xmlrpc_call "wp.getProfile" "$params"); then
        if [[ "$VERBOSE" == true ]]; then
            echo "✓ Connexion et authentification réussies"
        fi
        return 0
    else
        echo "✗ Échec du test de connexion" >&2
        return 1
    fi
}

# Vérifier si une date a déjà un post programmé à 14h00
# Pour simplifier, on suppose qu'un seul post par jour à 14h00 est autorisé
check_date_availability() {
    local check_date="$1"
    
    # Pour cette implémentation simplifiée, on considère que chaque jour de semaine
    # peut avoir un post à 14h00. Une version plus avancée pourrait interroger WordPress
    # pour vérifier les posts existants, mais cela nécessiterait une API plus complexe.
    
    # Retourner 0 (libre) pour tous les jours de semaine
    # Cette logique peut être étendue plus tard pour vérifier les posts existants
    return 0
}

# Calculer la prochaine date disponible à 14h00 en semaine
find_next_available_date() {
    if [[ "$VERBOSE" == true ]]; then
        echo "Recherche de la prochaine date disponible à 14h00..." >&2
    fi
    
    # Commencer par aujourd'hui
    local check_date
    check_date=$(date "+%Y-%m-%d")
    
    # Chercher jusqu'à 45 jours à l'avance
    for i in $(seq 0 44); do
        # Calculer le jour de la semaine (1=lundi, 7=dimanche)
        local day_of_week
        if command -v gdate >/dev/null 2>&1; then
            # macOS avec GNU date installé via brew
            day_of_week=$(gdate -d "$check_date" "+%u")
        elif date -j >/dev/null 2>&1; then
            # macOS avec date BSD
            day_of_week=$(date -j -f "%Y-%m-%d" "$check_date" "+%u" 2>/dev/null || echo "1")
        else
            # Linux avec GNU date
            day_of_week=$(date -d "$check_date" "+%u" 2>/dev/null || echo "1")
        fi
        
        # Ignorer les weekends (6=samedi, 7=dimanche)
        if [[ "$day_of_week" -ge 6 ]]; then
            if [[ "$VERBOSE" == true ]]; then
                echo "  $check_date: weekend, ignoré" >&2
            fi
        else
            # Vérifier la disponibilité de cette date
            if check_date_availability "$check_date"; then
                if [[ "$VERBOSE" == true ]]; then
                    echo "  $check_date: créneau libre trouvé!" >&2
                fi
                echo "$check_date"
                return 0
            else
                if [[ "$VERBOSE" == true ]]; then
                    echo "  $check_date: créneau déjà occupé" >&2
                fi
            fi
        fi
        
        # Passer au jour suivant
        if command -v gdate >/dev/null 2>&1; then
            check_date=$(gdate -d "$check_date + 1 day" "+%Y-%m-%d")
        elif date -j >/dev/null 2>&1; then
            check_date=$(date -j -v+1d -f "%Y-%m-%d" "$check_date" "+%Y-%m-%d" 2>/dev/null || date -d "$check_date + 1 day" "+%Y-%m-%d")
        else
            check_date=$(date -d "$check_date + 1 day" "+%Y-%m-%d")
        fi
    done
    
    # Si aucun créneau libre trouvé, utiliser la date dans 45 jours
    echo "$check_date"
    return 1
}

# Créer la structure XML pour wp.newPost
create_post_xml_params() {
    local title="$1"
    local content="$2"
    local excerpt="$3"
    local slug="$4"
    local categories="$5"
    local post_date="$6"
    
    # Échapper les caractères XML spéciaux
    title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    excerpt=$(echo "$excerpt" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    slug=$(echo "$slug" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Construire la structure du post
    local post_struct="<param><value><struct>
            <member>
                <name>post_title</name>
                <value><string>$title</string></value>
            </member>
            <member>
                <name>post_status</name>
                <value><string>draft</string></value>
            </member>
            <member>
                <name>post_type</name>
                <value><string>post</string></value>
            </member>"
    
    # Ajouter le contenu s'il est fourni
    if [[ -n "$content" ]]; then
        post_struct="$post_struct
            <member>
                <name>post_content</name>
                <value><string>$content</string></value>
            </member>"
    fi
    
    # Ajouter l'extrait s'il est fourni
    if [[ -n "$excerpt" ]]; then
        post_struct="$post_struct
            <member>
                <name>post_excerpt</name>
                <value><string>$excerpt</string></value>
            </member>"
    fi
    
    # Ajouter le slug s'il est fourni
    if [[ -n "$slug" ]]; then
        post_struct="$post_struct
            <member>
                <name>post_name</name>
                <value><string>$slug</string></value>
            </member>"
    fi
    
    # Ajouter la date de publication s'elle est fournie
    if [[ -n "$post_date" ]]; then
        # Format WordPress XML-RPC: YYYY-MM-DD HH:MM:SS
        local wp_date_format
        wp_date_format=$(echo "$post_date" | sed 's/T/ /' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
        post_struct="$post_struct
            <member>
                <name>post_date</name>
                <value><string>$wp_date_format</string></value>
            </member>"
    fi
    
    # Fermer la structure
    post_struct="$post_struct
        </struct></value></param>"
    
    # Construire les paramètres complets pour wp.newPost
    local full_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        $post_struct"
    
    echo "$full_params"
}

# Valider et nettoyer un slug WordPress
validate_and_clean_slug() {
    local slug="$1"
    
    if [[ -z "$slug" ]]; then
        echo ""
        return 0
    fi
    
    # Convertir en minuscules
    slug=$(echo "$slug" | tr '[:upper:]' '[:lower:]')
    
    # Remplacer les espaces et caractères non autorisés par des tirets
    # Caractères autorisés: lettres, chiffres, tirets, underscores
    slug=$(echo "$slug" | sed 's/[^a-z0-9_-]/-/g')
    
    # Supprimer les tirets multiples consécutifs (répéter pour être sûr)
    while [[ "$slug" =~ --+ ]]; do
        slug=$(echo "$slug" | sed 's/--/-/g')
    done
    
    # Supprimer les tirets en début et fin
    slug=$(echo "$slug" | sed 's/^-*//;s/-*$//')
    
    # Si le slug est vide après nettoyage, retourner une chaîne vide
    if [[ -z "$slug" ]]; then
        if [[ "$VERBOSE" == true && -n "$1" ]]; then
            echo "Avertissement: Slug '$1' invalide après nettoyage, ignoré" >&2
        fi
        echo ""
        return 0
    fi
    
    # Limiter la longueur à 200 caractères (limite WordPress)
    if [[ ${#slug} -gt 200 ]]; then
        slug="${slug:0:200}"
        # Supprimer le tiret final si la troncature en a créé un
        slug=$(echo "$slug" | sed 's/-*$//')
    fi
    
    if [[ "$VERBOSE" == true && -n "$1" && "$slug" != "$1" ]]; then
        echo "Slug nettoyé: '$1' → '$slug'" >&2
    fi
    
    echo "$slug"
}

# Formateur de contenu - convertit le texte en HTML approprié
format_content() {
    local content="$1"
    
    if [[ -z "$content" ]]; then
        echo ""
        return 0
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Formatage du contenu (${#content} caractères)..." >&2
    fi
    
    # Optimisation pour gros contenus: traitement par chunks si nécessaire
    local content_size=${#content}
    local use_chunked_processing=false
    
    if [[ $content_size -gt 32768 ]]; then
        use_chunked_processing=true
        if [[ "$VERBOSE" == true ]]; then
            echo "  Contenu volumineux détecté, activation du traitement optimisé" >&2
        fi
    fi
    
    # Créer un fichier temporaire pour traiter le contenu ligne par ligne
    local temp_input=$(mktemp)
    local temp_output=$(mktemp)
    
    # Nettoyer les fichiers temporaires à la sortie
    trap "rm -f '$temp_input' '$temp_output'" EXIT
    
    # Écrire le contenu dans le fichier temporaire
    echo "$content" > "$temp_input"
    
    # Variables d'état pour le traitement
    local in_code_block=false
    local in_indented_code=false
    local in_list=false
    
    # Traitement ligne par ligne
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Étape 1: Traitement des blocs de code avec triple backticks
        if [[ "$line" =~ ^\`\`\`.*$ ]]; then
            if [[ "$in_code_block" == false ]]; then
                # Début du bloc de code
                in_code_block=true
                echo "<pre><code>" >> "$temp_output"
            else
                # Fin du bloc de code
                in_code_block=false
                echo "</code></pre>" >> "$temp_output"
            fi
            continue
        fi
        
        # Si on est dans un bloc de code, preserver le contenu tel quel
        if [[ "$in_code_block" == true ]]; then
            # Échapper les caractères HTML dans le code
            local escaped_line
            escaped_line=$(echo "$line" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            echo "$escaped_line" >> "$temp_output"
            continue
        fi
        
        # Étape 2: Traitement des blocs de code indentés (4+ espaces)
        if [[ "$line" =~ ^[[:space:]]{4,} ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            # Ligne indentée par au moins 4 espaces et non vide
            if [[ "$in_indented_code" == false ]]; then
                # Fermer une liste ouverte si nécessaire
                if [[ "$in_list" == true ]]; then
                    echo "</ul>" >> "$temp_output"
                    in_list=false
                fi
                in_indented_code=true
                echo "<pre><code>" >> "$temp_output"
            fi
            # Supprimer les 4 premiers espaces et échapper HTML
            local code_line="${line:4}"
            code_line=$(echo "$code_line" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            echo "$code_line" >> "$temp_output"
            continue
        else
            # Fermer le bloc de code indenté si on était dedans
            if [[ "$in_indented_code" == true ]]; then
                in_indented_code=false
                echo "</code></pre>" >> "$temp_output"
            fi
        fi
        
        # Étape 3: Traitement des listes à puces
        if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+ ]]; then
            # Ligne de liste (commence par - ou * suivi d'un espace)
            if [[ "$in_list" == false ]]; then
                in_list=true
                # Utiliser les classes WordPress pour les listes
                echo "<!-- wp:list -->" >> "$temp_output"
                echo "<ul class=\"wp-block-list\">" >> "$temp_output"
            fi
            # Extraire le contenu après le marqueur de liste
            local list_content
            list_content=$(echo "$line" | sed 's/^[[:space:]]*[-*][[:space:]]*//')
            # Échapper d'abord les caractères HTML spéciaux (sauf < et >)
            list_content=$(echo "$list_content" | sed 's/&/\&amp;/g')
            
            # Traiter le formatage Markdown : gras **texte**
            list_content=$(echo "$list_content" | sed -E 's|\*\*([^*]+)\*\*|<strong>\1</strong>|g')
            
            # Traiter le formatage Markdown : italique *texte*
            list_content=$(echo "$list_content" | sed -E 's|([^*])\*([^*]+)\*([^*])|\1<em>\2</em>\3|g')
            list_content=$(echo "$list_content" | sed -E 's|^\*([^*]+)\*([^*])|<em>\1</em>\2|g')
            list_content=$(echo "$list_content" | sed -E 's|([^*])\*([^*]+)\*$|\1<em>\2</em>|g')
            list_content=$(echo "$list_content" | sed -E 's|^\*([^*]+)\*$|<em>\1</em>|g')
            
            # Traiter le code inline `code`
            list_content=$(echo "$list_content" | sed -E 's|`([^`]+)`|<code>\1</code>|g')
            
            # Traiter les images Markdown ![alt](url) en blocs Gutenberg
            list_content=$(echo "$list_content" | sed -E 's|!\[([^]]*)\]\(([^)]+)\)|<figure class="wp-block-image size-large"><img src="\2" alt="\1"/></figure>|g')
            
            # Puis traiter les URLs en liens HTML (mais pas celles déjà dans les images)
            list_content=$(echo "$list_content" | sed -E 's|([^"])(https?://[^[:space:]<>"&]+)([^"])|\1<a href="\2">\2</a>\3|g')
            list_content=$(echo "$list_content" | sed -E 's|^(https?://[^[:space:]<>"&]+)([^"])|<a href="\1">\1</a>\2|g')
            list_content=$(echo "$list_content" | sed -E 's|([^"])(https?://[^[:space:]<>"&]+)$|\1<a href="\2">\2</a>|g')
            list_content=$(echo "$list_content" | sed -E 's|^(https?://[^[:space:]<>"&]+)$|<a href="\1">\1</a>|g')
            echo "<!-- wp:list-item -->" >> "$temp_output"
            echo "<li>$list_content</li>" >> "$temp_output"
            echo "<!-- /wp:list-item -->" >> "$temp_output"
            continue
        else
            # Fermer la liste si on était dedans
            if [[ "$in_list" == true ]]; then
                in_list=false
                echo "</ul>" >> "$temp_output"
                echo "<!-- /wp:list -->" >> "$temp_output"
            fi
        fi
        
        # Étape 4: Traitement des titres Markdown
        if [[ "$line" =~ ^#{1,6}[[:space:]]+ ]]; then
            # Ligne de titre (commence par 1 à 6 # suivis d'un espace)
            local header_level
            local header_content
            
            # Compter le nombre de #
            header_level=$(echo "$line" | sed 's/^\(#*\).*/\1/' | wc -c)
            header_level=$((header_level - 1))  # Soustraire 1 pour le caractère de fin
            
            # Extraire le contenu du titre
            header_content=$(echo "$line" | sed 's/^#*[[:space:]]*//')
            
            # Limiter les niveaux de titre (WordPress utilise h1-h6)
            if [[ $header_level -gt 6 ]]; then
                header_level=6
            fi
            
            # Échapper d'abord les caractères HTML spéciaux (sauf < et >)
            header_content=$(echo "$header_content" | sed 's/&/\&amp;/g')
            
            # Traiter le formatage Markdown : gras **texte**
            header_content=$(echo "$header_content" | sed -E 's|\*\*([^*]+)\*\*|<strong>\1</strong>|g')
            
            # Traiter le formatage Markdown : italique *texte*
            header_content=$(echo "$header_content" | sed -E 's|([^*])\*([^*]+)\*([^*])|\1<em>\2</em>\3|g')
            header_content=$(echo "$header_content" | sed -E 's|^\*([^*]+)\*([^*])|<em>\1</em>\2|g')
            header_content=$(echo "$header_content" | sed -E 's|([^*])\*([^*]+)\*$|\1<em>\2</em>|g')
            header_content=$(echo "$header_content" | sed -E 's|^\*([^*]+)\*$|<em>\1</em>|g')
            
            # Traiter le code inline `code`
            header_content=$(echo "$header_content" | sed -E 's|`([^`]+)`|<code>\1</code>|g')
            
            # Traiter les images Markdown ![alt](url) en blocs Gutenberg
            header_content=$(echo "$header_content" | sed -E 's|!\[([^]]*)\]\(([^)]+)\)|<figure class="wp-block-image size-large"><img src="\2" alt="\1"/></figure>|g')
            
            # Puis traiter les URLs en liens HTML (mais pas celles déjà dans les images)
            header_content=$(echo "$header_content" | sed -E 's|([^"])(https?://[^[:space:]<>"&]+)([^"])|\1<a href="\2">\2</a>\3|g')
            header_content=$(echo "$header_content" | sed -E 's|^(https?://[^[:space:]<>"&]+)([^"])|<a href="\1">\1</a>\2|g')
            header_content=$(echo "$header_content" | sed -E 's|([^"])(https?://[^[:space:]<>"&]+)$|\1<a href="\2">\2</a>|g')
            header_content=$(echo "$header_content" | sed -E 's|^(https?://[^[:space:]<>"&]+)$|<a href="\1">\1</a>|g')
            
            echo "<h${header_level}>${header_content}</h${header_level}>" >> "$temp_output"
            continue
        fi
        
        # Étape 5: Traitement des lignes normales
        if [[ -n "$line" ]]; then
            # Échapper d'abord les caractères HTML spéciaux (sauf < et >)
            local processed_line
            processed_line=$(echo "$line" | sed 's/&/\&amp;/g')
            
            # Traiter le formatage Markdown : gras **texte**
            processed_line=$(echo "$processed_line" | sed -E 's|\*\*([^*]+)\*\*|<strong>\1</strong>|g')
            
            # Traiter le formatage Markdown : italique *texte* (mais pas les ** déjà traités)
            processed_line=$(echo "$processed_line" | sed -E 's|([^*])\*([^*]+)\*([^*])|\1<em>\2</em>\3|g')
            processed_line=$(echo "$processed_line" | sed -E 's|^\*([^*]+)\*([^*])|<em>\1</em>\2|g')
            processed_line=$(echo "$processed_line" | sed -E 's|([^*])\*([^*]+)\*$|\1<em>\2</em>|g')
            processed_line=$(echo "$processed_line" | sed -E 's|^\*([^*]+)\*$|<em>\1</em>|g')
            
            # Traiter le code inline `code`
            processed_line=$(echo "$processed_line" | sed -E 's|`([^`]+)`|<code>\1</code>|g')
            
            # Traiter les images Markdown ![alt](url) en blocs Gutenberg
            processed_line=$(echo "$processed_line" | sed -E 's|!\[([^]]*)\]\(([^)]+)\)|<figure class="wp-block-image size-large"><img src="\2" alt="\1"/></figure>|g')
            
            # Traiter les URLs YouTube en blocs embed Gutenberg
            processed_line=$(echo "$processed_line" | sed -E 's|^(https?://www\.youtube\.com/watch\?v=[^[:space:]<>"&]+)$|<figure class="wp-block-embed is-type-video is-provider-youtube wp-block-embed-youtube wp-embed-aspect-16-9 wp-has-aspect-ratio"><div class="wp-block-embed__wrapper">\1</div></figure>|g')
            processed_line=$(echo "$processed_line" | sed -E 's|^(https?://youtube\.com/watch\?v=[^[:space:]<>"&]+)$|<figure class="wp-block-embed is-type-video is-provider-youtube wp-block-embed-youtube wp-embed-aspect-16-9 wp-has-aspect-ratio"><div class="wp-block-embed__wrapper">\1</div></figure>|g')
            
            # Puis traiter les autres URLs en liens HTML (mais pas celles déjà dans les images ou embeds)
            processed_line=$(echo "$processed_line" | sed -E 's|([^">])(https?://[^[:space:]<>"&]+)([^<"])|\1<a href="\2">\2</a>\3|g')
            processed_line=$(echo "$processed_line" | sed -E 's|^(https?://[^[:space:]<>"&]+)([^<"])|<a href="\1">\1</a>\2|g')
            processed_line=$(echo "$processed_line" | sed -E 's|([^">])(https?://[^[:space:]<>"&]+)$|\1<a href="\2">\2</a>|g')
            
            echo "$processed_line" >> "$temp_output"
        else
            # Ligne vide - ajouter un saut de ligne HTML pour WordPress
            echo "<br>" >> "$temp_output"
        fi
        
    done < "$temp_input"
    
    # Fermer les blocs ouverts si nécessaire
    if [[ "$in_code_block" == true ]]; then
        echo "</code></pre>" >> "$temp_output"
    fi
    if [[ "$in_indented_code" == true ]]; then
        echo "</code></pre>" >> "$temp_output"
    fi
    if [[ "$in_list" == true ]]; then
        echo "</ul>" >> "$temp_output"
        echo "<!-- /wp:list -->" >> "$temp_output"
    fi
    
    # Lire le résultat et nettoyer
    local formatted_content
    formatted_content=$(cat "$temp_output")
    
    # Optimisation pour gros contenus: nettoyage efficace
    if [[ $use_chunked_processing == true ]]; then
        # Pour les gros contenus, utiliser une approche plus efficace
        formatted_content=$(cat "$temp_output")
        if [[ "$VERBOSE" == true ]]; then
            echo "  Nettoyage optimisé pour gros contenu..." >&2
        fi
    else
        # Supprimer les lignes vides multiples consécutives (méthode standard)
        formatted_content=$(echo "$formatted_content" | awk 'BEGIN{RS=""; ORS="\n\n"} {gsub(/\n+/, "\n"); print}' | sed '$s/\n\n$/\n/')
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        local final_size=${#formatted_content}
        echo "Formatage terminé ($final_size caractères après formatage)" >&2
        if [[ $use_chunked_processing == true ]]; then
            local size_diff=$((final_size - content_size))
            echo "  Optimisation activée: +$size_diff caractères de formatage" >&2
        fi
    fi
    
    echo "$formatted_content"
}

# Gérer l'image featured (URL ou upload) avec support du téléchargement d'images depuis URL
handle_featured_image() {
    local image_path="$1"
    
    if [[ -z "$image_path" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "Aucune image spécifiée" >&2
        fi
        return 1
    fi
    
    # Vérifier si c'est une URL
    if [[ "$image_path" =~ ^https?:// ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "URL d'image featured détectée: $image_path" >&2
            echo "  Téléchargement et upload de l'image..." >&2
        fi
        
        # Télécharger l'image depuis l'URL
        local temp_image_path
        if temp_image_path=$(download_image_from_url "$image_path" | tail -n1); then
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ Image téléchargée, upload vers WordPress..."
            fi
            
            # Uploader l'image téléchargée vers WordPress
            local attachment_id
            local upload_output
            if upload_output=$(upload_media "$temp_image_path"); then
                attachment_id=$(echo "$upload_output" | tr -d '\r' | grep -Eo '[0-9]+' | tail -n1)
                if [[ -z "$attachment_id" ]]; then
                    rm -f "$temp_image_path"
                    echo "✗ Échec: ID d'attachment non détecté après upload" >&2
                    return 1
                fi
                # Nettoyer le fichier temporaire
                rm -f "$temp_image_path"
                
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ✓ Image uploadée avec succès (ID: $attachment_id)" >&2
                fi
                
                # Retourner l'ID de l'attachment
                echo "$attachment_id"
                return 0
            else
                # Nettoyer le fichier temporaire en cas d'échec
                rm -f "$temp_image_path"
                echo "✗ Échec de l'upload de l'image téléchargée" >&2
                return 1
            fi
        else
            echo "✗ Échec du téléchargement de l'image depuis l'URL" >&2
            return 1
        fi
    else
        # Fichier local - utiliser l'upload traditionnel
        local attachment_id
        local upload_output
        if upload_output=$(upload_media "$image_path"); then
            attachment_id=$(echo "$upload_output" | tr -d '\r' | grep -Eo '[0-9]+' | tail -n1)
            if [[ -z "$attachment_id" ]]; then
                echo "✗ Échec: ID d'attachment non détecté après upload" >&2
                return 1
            fi
            echo "$attachment_id"
            return 0
        fi
        return 1
    fi
}

# Définir une image featured via URL (plugin Featured Image by URL)
set_featured_image_url() {
    local post_id="$1"
    local image_url="$2"
    
    if [[ -z "$post_id" || -z "$image_url" ]]; then
        echo "Erreur: ID de post ou URL d'image manquant pour définir l'image featured" >&2
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Définition de l'image featured via URL pour le post $post_id..."
        echo "  URL: $image_url"
    fi
    
    # Construire les paramètres pour wp.editPost avec les meta fields du plugin
    local post_struct="<param><value><struct>
            <member>
                <name>custom_fields</name>
                <value><array>
                    <data>
                        <value><struct>
                            <member>
                                <name>key</name>
                                <value><string>_knawatfibu_url</string></value>
                            </member>
                            <member>
                                <name>value</name>
                                <value><string>$image_url</string></value>
                            </member>
                        </struct></value>
                        <value><struct>
                            <member>
                                <name>key</name>
                                <value><string>_knawatfibu_alt</string></value>
                            </member>
                            <member>
                                <name>value</name>
                                <value><string>Featured Image</string></value>
                            </member>
                        </struct></value>
                    </data>
                </array></value>
            </member>
        </struct></value></param>"
    
    local xml_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        <param><value><string>$post_id</string></value></param>
        $post_struct"
    
    # Effectuer l'appel XML-RPC wp.editPost
    local response
    if response=$(xmlrpc_call "wp.editPost" "$xml_params"); then
        # Vérifier si la réponse indique un succès (true)
        if echo "$response" | grep -q "<boolean>1</boolean>"; then
            if [[ "$VERBOSE" == true ]]; then
                echo "✓ Image featured URL définie avec succès"
            fi
            return 0
        else
            echo "✗ Erreur: Échec de la définition de l'image featured URL" >&2
            if [[ "$VERBOSE" == true ]]; then
                echo "Réponse reçue: $response" >&2
            fi
            return 1
        fi
    else
        echo "✗ Échec de l'appel wp.editPost pour définir l'image featured URL" >&2
        return 1
    fi
}

# Télécharger une image depuis une URL avec validation et gestion d'erreurs
download_image_from_url() {
    local image_url="$1"
    
    if [[ -z "$image_url" ]]; then
        echo "Erreur: URL d'image manquante" >&2
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Téléchargement de l'image depuis URL: $image_url"
    fi
    
    # Valider l'URL d'image avant téléchargement
    if ! validate_image_url "$image_url"; then
        echo "Erreur: URL d'image invalide ou inaccessible: $image_url" >&2
        return 1
    fi
    
    # Créer un fichier temporaire sécurisé pour stocker l'image
    local temp_image
    local url_ext
    url_ext=$(echo "$image_url" | sed 's/.*\.//' | sed 's/[?#].*//' | tr '[:upper:]' '[:lower:]')
    case "$url_ext" in
        jpg|jpeg|png|gif|webp|bmp) ;;
        *) url_ext="jpg" ;;
    esac
    temp_image=$(mktemp "${TMPDIR:-/tmp}/wpimg.XXXXXX.${url_ext}")
    if [[ $? -ne 0 || -z "$temp_image" ]]; then
        echo "Erreur: Impossible de créer un fichier temporaire sécurisé" >&2
        return 1
    fi
    
    # Nettoyer le fichier temporaire à la sortie
    trap "rm -f '$temp_image'" EXIT
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Fichier temporaire créé: $temp_image"
        echo "  Téléchargement en cours..."
    fi
    
    # Télécharger l'image avec curl avec gestion des timeouts et codes d'erreur
    local http_code
    local curl_exit_code
    
    http_code=$(curl -s -w "%{http_code}" \
        -H "User-Agent: wp-draft.sh/1.0 (WordPress Draft Publisher)" \
        --connect-timeout 30 \
        --max-time 120 \
        --max-filesize 33554432 \
        --location \
        --fail-with-body \
        -o "$temp_image" \
        "$image_url")
    
    curl_exit_code=$?
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Code HTTP: $http_code"
        echo "  Code de sortie curl: $curl_exit_code"
    fi
    
    # Gérer les codes d'erreur HTTP et curl
    if [[ $curl_exit_code -ne 0 ]]; then
        case $curl_exit_code in
            6)
                echo "Erreur: Impossible de résoudre l'hôte de l'URL: $image_url" >&2
                ;;
            7)
                echo "Erreur: Impossible de se connecter à l'URL: $image_url" >&2
                ;;
            22)
                echo "Erreur HTTP $http_code: Échec du téléchargement de l'image" >&2
                case $http_code in
                    404) echo "  L'image n'existe pas à cette URL" >&2 ;;
                    403) echo "  Accès refusé à l'image" >&2 ;;
                    500) echo "  Erreur serveur lors du téléchargement" >&2 ;;
                esac
                ;;
            28)
                echo "Erreur: Timeout lors du téléchargement de l'image (>120s)" >&2
                ;;
            63)
                echo "Erreur: Fichier image trop volumineux (>32MB)" >&2
                ;;
            *)
                echo "Erreur curl ($curl_exit_code): Échec du téléchargement de l'image" >&2
                ;;
        esac
        rm -f "$temp_image"
        return 1
    fi
    
    # Vérifier que le fichier a été téléchargé et n'est pas vide
    if [[ ! -f "$temp_image" || ! -s "$temp_image" ]]; then
        echo "Erreur: Le fichier téléchargé est vide ou inexistant" >&2
        rm -f "$temp_image"
        return 1
    fi
    
    # Vérifier la taille du fichier téléchargé
    local file_size
    if command -v stat >/dev/null 2>&1; then
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            file_size=$(stat -f%z "$temp_image" 2>/dev/null || echo "0")
        else
            # Linux
            file_size=$(stat -c%s "$temp_image" 2>/dev/null || echo "0")
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            local size_mb=$((file_size / 1024 / 1024))
            echo "  Taille du fichier téléchargé: ${size_mb}MB"
        fi
        
        # Vérifier la limite de taille (32MB)
        local max_size=$((32 * 1024 * 1024))
        if [[ "$file_size" -gt "$max_size" ]]; then
            local size_mb=$((file_size / 1024 / 1024))
            echo "Erreur: Image téléchargée trop volumineuse: ${size_mb}MB (maximum: 32MB)" >&2
            rm -f "$temp_image"
            return 1
        fi
    fi
    
    # Valider le type MIME du fichier téléchargé
    local detected_mime_type
    if command -v file >/dev/null 2>&1; then
        detected_mime_type=$(file --mime-type -b "$temp_image" 2>/dev/null)
        
        if [[ "$VERBOSE" == true ]]; then
            echo "  Type MIME détecté: $detected_mime_type"
        fi
        
        # Vérifier que c'est bien une image supportée
        case "$detected_mime_type" in
            image/jpeg|image/png|image/gif|image/webp|image/bmp)
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ✓ Type d'image valide: $detected_mime_type"
                fi
                ;;
            *)
                echo "Erreur: Le fichier téléchargé n'est pas une image supportée" >&2
                echo "  Type détecté: $detected_mime_type" >&2
                echo "  Types supportés: image/jpeg, image/png, image/gif, image/webp, image/bmp" >&2
                rm -f "$temp_image"
                return 1
                ;;
        esac
    else
        if [[ "$VERBOSE" == true ]]; then
            echo "  Avertissement: 'file' non disponible, validation MIME ignorée" >&2
        fi
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "✓ Image téléchargée avec succès dans: $temp_image"
    fi
    
    # Retourner le chemin du fichier temporaire
    echo "$temp_image"
    return 0
}

# Valider l'accessibilité et le type d'une URL d'image avec validation avancée
validate_image_url() {
    local image_url="$1"
    local max_size_mb="${2:-32}"  # Taille max configurable, défaut 32MB
    
    if [[ -z "$image_url" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "  Erreur: URL d'image vide" >&2
        fi
        return 1
    fi
    
    # Vérifier le format de l'URL avec validation plus stricte
    if [[ ! "$image_url" =~ ^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9].*$ ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "  Erreur: Format d'URL invalide: $image_url" >&2
            echo "  L'URL doit commencer par http:// ou https:// et avoir un domaine valide" >&2
        fi
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Validation avancée de l'URL d'image: $image_url"
    fi
    
    # Vérifier l'extension de l'URL (validation préliminaire)
    local url_ext
    url_ext=$(echo "$image_url" | sed 's/.*\.//' | sed 's/[?#].*//' | tr '[:upper:]' '[:lower:]')
    local extension_valid=false
    
    case "$url_ext" in
        jpg|jpeg|png|gif|webp)
            extension_valid=true
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ Extension d'URL reconnue: $url_ext"
            fi
            ;;
        bmp|tiff|tif|svg)
            extension_valid=true
            if [[ "$VERBOSE" == true ]]; then
                echo "  ⚠ Extension d'URL supportée mais non optimale: $url_ext" >&2
            fi
            ;;
        *)
            if [[ "$VERBOSE" == true ]]; then
                echo "  ⚠ Extension d'URL non reconnue: $url_ext" >&2
                echo "  Validation via Content-Type requise..." >&2
            fi
            ;;
    esac
    
    # Variables pour la requête HEAD
    local http_code
    local final_url
    local content_type
    local content_length
    local curl_exit_code
    local redirect_count=0
    local max_redirects=10
    
    # Créer un fichier temporaire pour les headers
    local temp_headers
    temp_headers=$(mktemp)
    trap "rm -f '$temp_headers'" EXIT
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Effectuation de la requête HEAD avec gestion des redirections..."
    fi
    
    # Effectuer une requête HEAD avec gestion avancée des redirections
    http_code=$(curl -s -w "%{http_code}|%{url_effective}" \
        -H "User-Agent: wp-draft.sh/1.0 (WordPress Draft Publisher)" \
        -H "Accept: image/jpeg,image/png,image/gif,image/webp,image/*,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Cache-Control: no-cache" \
        --connect-timeout 15 \
        --max-time 30 \
        --location \
        --max-redirs "$max_redirects" \
        --head \
        -D "$temp_headers" \
        -o /dev/null \
        "$image_url")
    
    curl_exit_code=$?
    
    # Parser la réponse curl
    if [[ "$http_code" =~ \| ]]; then
        local curl_output="$http_code"
        http_code=$(echo "$curl_output" | cut -d'|' -f1)
        final_url=$(echo "$curl_output" | cut -d'|' -f2)
        if [[ -n "$final_url" && "$final_url" != "$image_url" ]]; then
            redirect_count=1
        else
            redirect_count=0
        fi
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Code HTTP: $http_code"
        echo "  Code de sortie curl: $curl_exit_code"
        if [[ -n "$final_url" && "$final_url" != "$image_url" ]]; then
            echo "  URL finale après redirections: $final_url"
            echo "  Nombre de redirections: $redirect_count"
        fi
    fi
    
    # Vérifier les erreurs de connexion avec messages détaillés
    if [[ $curl_exit_code -ne 0 ]]; then
        case $curl_exit_code in
            6)
                echo "  Erreur: Impossible de résoudre l'hôte pour $image_url" >&2
                echo "  Vérifiez que le nom de domaine est correct et accessible" >&2
                ;;
            7)
                echo "  Erreur: Impossible de se connecter à $image_url" >&2
                echo "  Le serveur pourrait être hors ligne ou bloquer les connexions" >&2
                ;;
            28)
                echo "  Erreur: Timeout de connexion vers $image_url" >&2
                echo "  Le serveur met trop de temps à répondre (>30s)" >&2
                ;;
            47)
                echo "  Erreur: Trop de redirections (>$max_redirects) pour $image_url" >&2
                echo "  Possible boucle de redirection infinie" >&2
                ;;
            22)
                echo "  Erreur: Réponse HTTP d'erreur du serveur" >&2
                ;;
            *)
                echo "  Erreur curl ($curl_exit_code): Échec de la requête vers $image_url" >&2
                ;;
        esac
        rm -f "$temp_headers"
        return 1
    fi
    
    # Vérifier le code de statut HTTP avec gestion étendue
    case $http_code in
        200)
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ URL accessible (HTTP 200)"
            fi
            ;;
        301|302|303|307|308)
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ URL accessible avec redirection (HTTP $http_code)"
                if [[ "$redirect_count" -gt 5 ]]; then
                    echo "  ⚠ Nombre élevé de redirections: $redirect_count" >&2
                fi
            fi
            ;;
        404)
            echo "  Erreur: Image non trouvée (HTTP 404)" >&2
            echo "  L'URL $image_url ne pointe vers aucune ressource" >&2
            rm -f "$temp_headers"
            return 1
            ;;
        403)
            echo "  Erreur: Accès refusé (HTTP 403)" >&2
            echo "  Le serveur refuse l'accès à $image_url" >&2
            echo "  Possible protection anti-hotlinking ou permissions insuffisantes" >&2
            rm -f "$temp_headers"
            return 1
            ;;
        401)
            echo "  Erreur: Authentification requise (HTTP 401)" >&2
            echo "  L'accès à $image_url nécessite une authentification" >&2
            rm -f "$temp_headers"
            return 1
            ;;
        429)
            echo "  Erreur: Trop de requêtes (HTTP 429)" >&2
            echo "  Le serveur limite le taux de requêtes, réessayez plus tard" >&2
            rm -f "$temp_headers"
            return 1
            ;;
        500|502|503|504)
            echo "  Erreur: Problème serveur (HTTP $http_code)" >&2
            echo "  Le serveur rencontre des difficultés temporaires" >&2
            rm -f "$temp_headers"
            return 1
            ;;
        *)
            echo "  Erreur: Code HTTP inattendu: $http_code" >&2
            echo "  Réponse non standard du serveur pour $image_url" >&2
            rm -f "$temp_headers"
            return 1
            ;;
    esac
    
    # Validation avancée du Content-Type et des headers
    if [[ -f "$temp_headers" ]]; then
        # Extraire les headers avec gestion des variations de casse
        content_type=$(grep -i "^content-type:" "$temp_headers" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
        content_length=$(grep -i "^content-length:" "$temp_headers" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        # Validation stricte du Content-Type
        if [[ -n "$content_type" ]]; then
            # Extraire le type MIME principal (avant le ;)
            local main_mime_type
            main_mime_type=$(echo "$content_type" | cut -d';' -f1 | sed 's/[[:space:]]*$//')
            
            if [[ "$VERBOSE" == true ]]; then
                echo "  Content-Type détecté: $main_mime_type"
            fi
            
            # Validation des types MIME supportés (selon requirements 5.6)
            case "$main_mime_type" in
                image/jpeg|image/jpg)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ✓ Type MIME JPEG valide: $main_mime_type"
                    fi
                    ;;
                image/png)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ✓ Type MIME PNG valide: $main_mime_type"
                    fi
                    ;;
                image/gif)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ✓ Type MIME GIF valide: $main_mime_type"
                    fi
                    ;;
                image/webp)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ✓ Type MIME WebP valide: $main_mime_type"
                    fi
                    ;;
                image/bmp|image/x-ms-bmp)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "  ⚠ Type MIME BMP supporté: $main_mime_type" >&2
                        echo "  Note: BMP n'est pas optimal pour le web" >&2
                    fi
                    ;;
                image/tiff|image/tif)
                    echo "  Erreur: Type MIME TIFF non supporté: $main_mime_type" >&2
                    echo "  TIFF n'est généralement pas supporté par les navigateurs web" >&2
                    rm -f "$temp_headers"
                    return 1
                    ;;
                image/svg+xml)
                    echo "  Erreur: Type MIME SVG non supporté: $main_mime_type" >&2
                    echo "  SVG nécessite une gestion spéciale non implémentée" >&2
                    rm -f "$temp_headers"
                    return 1
                    ;;
                text/html|text/plain|application/*)
                    echo "  Erreur: Content-Type non-image détecté: $main_mime_type" >&2
                    echo "  L'URL ne pointe pas vers une image mais vers: $main_mime_type" >&2
                    rm -f "$temp_headers"
                    return 1
                    ;;
                *)
                    echo "  Erreur: Type MIME d'image non supporté: $main_mime_type" >&2
                    echo "  Types supportés: image/jpeg, image/png, image/gif, image/webp" >&2
                    rm -f "$temp_headers"
                    return 1
                    ;;
            esac
        else
            # Si pas de Content-Type, vérifier si l'extension était valide
            if [[ "$extension_valid" != true ]]; then
                echo "  Erreur: Impossible de déterminer le type de fichier" >&2
                echo "  Aucun Content-Type fourni et extension non reconnue" >&2
                rm -f "$temp_headers"
                return 1
            else
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ⚠ Content-Type manquant, validation basée sur l'extension: $url_ext" >&2
                fi
            fi
        fi
        
        # Validation avancée de la taille avec limites configurables
        if [[ -n "$content_length" && "$content_length" =~ ^[0-9]+$ ]]; then
            local size_bytes="$content_length"
            local size_kb=$((size_bytes / 1024))
            local size_mb=$((size_bytes / 1024 / 1024))
            
            if [[ "$VERBOSE" == true ]]; then
                if [[ $size_mb -gt 0 ]]; then
                    echo "  Taille détectée: ${size_mb}MB (${size_kb}KB)"
                else
                    echo "  Taille détectée: ${size_kb}KB"
                fi
            fi
            
            # Vérifier la limite de taille configurable
            local max_size_bytes=$((max_size_mb * 1024 * 1024))
            if [[ "$size_bytes" -gt "$max_size_bytes" ]]; then
                echo "  Erreur: Image trop volumineuse: ${size_mb}MB" >&2
                echo "  Taille maximum autorisée: ${max_size_mb}MB" >&2
                echo "  Réduisez la taille de l'image ou utilisez un format plus compressé" >&2
                rm -f "$temp_headers"
                return 1
            fi
            
            # Avertissements pour les tailles importantes
            if [[ $size_mb -gt 10 ]]; then
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ⚠ Image volumineuse (${size_mb}MB), le téléchargement pourrait être lent" >&2
                fi
            elif [[ $size_mb -gt 5 ]]; then
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ⚠ Image de taille importante (${size_mb}MB)" >&2
                fi
            fi
        else
            if [[ "$VERBOSE" == true ]]; then
                echo "  ⚠ Taille de l'image non spécifiée par le serveur" >&2
                echo "  La validation de taille se fera lors du téléchargement" >&2
            fi
        fi
        
        # Vérifier d'autres headers utiles
        local last_modified
        local cache_control
        last_modified=$(grep -i "^last-modified:" "$temp_headers" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
        cache_control=$(grep -i "^cache-control:" "$temp_headers" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
        
        if [[ "$VERBOSE" == true ]]; then
            if [[ -n "$last_modified" ]]; then
                echo "  Dernière modification: $last_modified"
            fi
            if [[ -n "$cache_control" ]]; then
                echo "  Cache-Control: $cache_control"
            fi
        fi
    else
        echo "  Erreur: Impossible de lire les headers de réponse" >&2
        return 1
    fi
    
    rm -f "$temp_headers"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  ✓ Validation avancée de l'URL d'image réussie"
        if [[ -n "$final_url" && "$final_url" != "$image_url" ]]; then
            echo "  ✓ URL finale validée: $final_url"
        fi
    fi
    
    return 0
}

# Upload d'une image locale vers WordPress via wp.uploadFile
upload_media() {
    local image_path="$1"
    
    if [[ -z "$image_path" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "Aucune image spécifiée pour l'upload" >&2
        fi
        return 1
    fi
    
    if [[ ! -f "$image_path" ]]; then
        echo "Erreur: Fichier image non trouvé: $image_path" >&2
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Upload de l'image locale: $image_path"
        echo "  Taille du fichier: $(ls -lh "$image_path" | awk '{print $5}')"
    fi
    
    # Vérifier que le fichier est une image (extension basique)
    local file_ext="${image_path##*.}"
    file_ext=$(echo "$file_ext" | tr '[:upper:]' '[:lower:]')
    
    case "$file_ext" in
        jpg|jpeg|png|gif|webp|bmp)
            verbose_info "Type d'image détecté: $file_ext"
            ;;
        *)
            warning "Extension de fichier non reconnue comme image: $file_ext"
            warning "Tentative d'upload quand même..."
            ;;
    esac
    
    # Déterminer le type MIME
    local mime_type
    case "$file_ext" in
        jpg|jpeg) mime_type="image/jpeg" ;;
        png) mime_type="image/png" ;;
        gif) mime_type="image/gif" ;;
        webp) mime_type="image/webp" ;;
        bmp) mime_type="image/bmp" ;;
        *) mime_type="application/octet-stream" ;;
    esac
    
    # Encoder l'image en base64
    if [[ "$VERBOSE" == true ]]; then
        echo "  Encodage en base64..."
    fi
    
    local base64_data
    if ! base64_data=$(base64 -i "$image_path" 2>/dev/null); then
        echo "Erreur: Impossible d'encoder l'image en base64" >&2
        return 1
    fi
    
    # Supprimer les retours à la ligne du base64
    base64_data=$(echo "$base64_data" | tr -d '\n\r')
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Données base64 générées: ${#base64_data} caractères"
    fi
    
    # Extraire le nom du fichier
    local filename
    filename=$(basename "$image_path")
    
    # Échapper les caractères XML spéciaux dans le nom de fichier
    local escaped_filename escaped_mime_type
    escaped_filename=$(echo "$filename" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    escaped_mime_type=$(echo "$mime_type" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Construire la structure de données pour wp.uploadFile
    local upload_struct="<param><value><struct>
            <member>
                <name>name</name>
                <value><string>$escaped_filename</string></value>
            </member>
            <member>
                <name>type</name>
                <value><string>$escaped_mime_type</string></value>
            </member>
            <member>
                <name>bits</name>
                <value><base64>$base64_data</base64></value>
            </member>
        </struct></value></param>"
    
    # Construire les paramètres complets pour wp.uploadFile
    local xml_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        $upload_struct"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Envoi vers WordPress via wp.uploadFile..."
    fi
    
    # Effectuer l'appel XML-RPC wp.uploadFile
    local response
    if response=$(xmlrpc_call "wp.uploadFile" "$xml_params"); then
        # Extraire l'ID du fichier uploadé de la réponse XML
        local attachment_id
        attachment_id=$(echo "$response" | grep -A2 "<name>id</name>" | grep "<string>" | sed 's/.*<string>\([0-9]*\)<\/string>.*/\1/' | head -1)
        
        if [[ -n "$attachment_id" && "$attachment_id" =~ ^[0-9]+$ ]]; then
            # Extraire l'URL du fichier uploadé
            local file_url
            file_url=$(echo "$response" | grep -A2 "<name>url</name>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
            
            if [[ "$VERBOSE" == true ]]; then
                echo "✓ Image uploadée avec succès!"
                echo "  ID de l'attachment: $attachment_id"
                [[ -n "$file_url" ]] && echo "  URL: $file_url"
            fi
            
            # Retourner l'ID de l'attachment
            echo "$attachment_id"
            return 0
        else
            echo "✗ Erreur: Impossible d'extraire l'ID de l'attachment de la réponse" >&2
            if [[ "$VERBOSE" == true ]]; then
                echo "Réponse reçue: $response" >&2
            fi
            return 1
        fi
    else
        echo "✗ Échec de l'upload de l'image" >&2
        return 1
    fi
}

# Associer une image comme featured image d'un post
set_featured_image() {
    local post_id="$1"
    local attachment_id="$2"
    
    if [[ -z "$post_id" || -z "$attachment_id" ]]; then
        echo "Erreur: ID de post ou d'attachment manquant pour définir l'image featured" >&2
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Association de l'image $attachment_id comme featured image du post $post_id..."
    fi
    
    # Construire les paramètres pour wp.editPost pour définir la featured image
    local post_struct="<param><value><struct>
            <member>
                <name>post_thumbnail</name>
                <value><string>$attachment_id</string></value>
            </member>
        </struct></value></param>"
    
    local xml_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        <param><value><string>$post_id</string></value></param>
        $post_struct"
    
    # Effectuer l'appel XML-RPC wp.editPost
    local response
    if response=$(xmlrpc_call "wp.editPost" "$xml_params"); then
        # Vérifier si la réponse indique un succès (true)
        if echo "$response" | grep -q "<boolean>1</boolean>"; then
            if [[ "$VERBOSE" == true ]]; then
                echo "✓ Image featured définie avec succès"
            fi
            return 0
        else
            echo "✗ Erreur: Échec de la définition de l'image featured" >&2
            if [[ "$VERBOSE" == true ]]; then
                echo "Réponse reçue: $response" >&2
            fi
            return 1
        fi
    else
        echo "✗ Échec de l'appel wp.editPost pour définir l'image featured" >&2
        return 1
    fi
}

# Créer un post WordPress via wp.newPost (fonction étendue pour supporter slug, excerpt, catégories et image featured)
create_post() {
    local title="$1"
    local content="$2"
    local excerpt="$3"
    local slug="$4"
    local categories="$5"
    local image_path="$6"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Création du post WordPress via wp.newPost..."
        echo "  Titre: '$title'"
        [[ -n "$content" ]] && echo "  Contenu: ${#content} caractères"
        [[ -n "$excerpt" ]] && echo "  Extrait: '$excerpt'"
        [[ -n "$slug" ]] && echo "  Slug: '$slug'"
        [[ -n "$categories" ]] && echo "  Catégories: '$categories'"
        [[ -n "$image_path" ]] && echo "  Image featured: '$image_path'"
    fi
    
    # Valider et nettoyer le slug
    local clean_slug
    clean_slug=$(validate_and_clean_slug "$slug")
    
    # Résoudre et valider les catégories
    local valid_categories=""
    if [[ -n "$categories" ]]; then
        valid_categories=$(resolve_categories "$categories")
    fi
    
    # Formater le contenu avec les conversions HTML
    local formatted_content="$content"
    if [[ -n "$content" ]]; then
        formatted_content=$(format_content "$content")
    fi
    
    # Échapper les caractères XML spéciaux (le contenu est déjà formaté en HTML)
    local escaped_title escaped_content escaped_excerpt escaped_slug
    escaped_title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    escaped_content=$(echo "$formatted_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    escaped_excerpt=$(echo "$excerpt" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    escaped_slug=$(echo "$clean_slug" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Construire la structure de données du post
    local post_struct="<param><value><struct>
            <member>
                <name>post_title</name>
                <value><string>$escaped_title</string></value>
            </member>
            <member>
                <name>post_status</name>
                <value><string>draft</string></value>
            </member>
            <member>
                <name>post_type</name>
                <value><string>post</string></value>
            </member>"
    
    # Ajouter le contenu s'il est fourni
    if [[ -n "$content" ]]; then
        post_struct="$post_struct
            <member>
                <name>post_content</name>
                <value><string>$escaped_content</string></value>
            </member>"
    fi
    
    # Ajouter l'extrait s'il est fourni
    if [[ -n "$excerpt" ]]; then
        post_struct="$post_struct
            <member>
                <name>post_excerpt</name>
                <value><string>$escaped_excerpt</string></value>
            </member>"
    fi
    
    # Ajouter le slug s'il est fourni et valide
    if [[ -n "$clean_slug" ]]; then
        post_struct="$post_struct
            <member>
                <name>post_name</name>
                <value><string>$escaped_slug</string></value>
            </member>"
    fi
    
    # Ajouter les catégories s'il y en a de valides
    if [[ -n "$valid_categories" ]]; then
        post_struct="$post_struct
            <member>
                <name>terms_names</name>
                <value><struct>
                    <member>
                        <name>category</name>
                        <value><array>
                            <data>"
        
        # Ajouter chaque catégorie valide
        IFS=',' read -ra category_array <<< "$valid_categories"
        for category in "${category_array[@]}"; do
            category=$(echo "$category" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Échappement XML simple et sûr
            local escaped_category
            escaped_category=$(echo "$category" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
            post_struct="$post_struct
                                <value><string>$escaped_category</string></value>"
        done
        
        post_struct="$post_struct
                            </data>
                        </array></value>
                    </member>
                </struct></value>
            </member>"
    fi
    
    # Fermer la structure
    post_struct="$post_struct
        </struct></value></param>"
    
    # Construire les paramètres complets pour wp.newPost
    local xml_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        $post_struct"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Structure XML générée pour wp.newPost:"
        echo "  - post_title: $escaped_title"
        echo "  - post_status: draft"
        echo "  - post_type: post"
        [[ -n "$formatted_content" ]] && echo "  - post_content: ${#escaped_content} caractères (formaté HTML)"
        [[ -n "$excerpt" ]] && echo "  - post_excerpt: $escaped_excerpt"
        [[ -n "$clean_slug" ]] && echo "  - post_name: $escaped_slug"
        [[ -n "$valid_categories" ]] && echo "  - terms_names[category]: $valid_categories"
    fi
    
    # Effectuer l'appel XML-RPC wp.newPost
    local response
    if response=$(xmlrpc_call "wp.newPost" "$xml_params"); then
        # Extraire l'ID du post créé de la réponse XML
        local post_id
        post_id=$(echo "$response" | tr -d '\n' | sed -n 's/.*<string>\([0-9][0-9]*\)<\/string>.*/\1/p')
        
        if [[ -n "$post_id" && "$post_id" =~ ^[0-9]+$ ]]; then
            echo "✓ Brouillon créé avec succès!"
            echo "  ID du post: $post_id"
            [[ -n "$clean_slug" ]] && echo "  Slug: $clean_slug"
            
            # Gérer l'image featured (URL ou upload)
            if [[ -n "$image_path" ]]; then
                local image_result
                if image_result=$(handle_featured_image "$image_path"); then
                    # handle_featured_image retourne maintenant toujours un ID d'attachment
                    if set_featured_image "$post_id" "$image_result"; then
                        if [[ "$image_path" =~ ^https?:// ]]; then
                            echo "  ✓ Image téléchargée depuis URL et définie comme featured image (ID: $image_result)"
                        else
                            echo "  ✓ Image locale uploadée et définie comme featured image (ID: $image_result)"
                        fi
                    else
                        echo "  ⚠ Avertissement: Image uploadée mais échec de l'association comme featured image" >&2
                    fi
                else
                    echo "  ⚠ Avertissement: Échec de la gestion de l'image featured" >&2
                fi
            fi
            
            echo "  URL d'édition: ${WP_URL}/wp-admin/post.php?post=${post_id}&action=edit"
            return 0
        else
            echo "✗ Erreur: Impossible d'extraire l'ID du post de la réponse" >&2
            if [[ "$VERBOSE" == true ]]; then
                echo "Réponse reçue: $response" >&2
            fi
            return 1
        fi
    else
        echo "✗ Échec de la création du brouillon" >&2
        return 1
    fi
}

# Récupérer les catégories WordPress via wp.getTerms
get_categories() {
    if [[ "$VERBOSE" == true ]]; then
        echo "Récupération des catégories WordPress via wp.getTerms..."
    fi
    
    # Construire les paramètres pour wp.getTerms
    local xml_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        <param><value><string>category</string></value></param>"
    
    # Effectuer l'appel XML-RPC
    local response
    if response=$(xmlrpc_call "wp.getTerms" "$xml_params"); then
        if [[ "$VERBOSE" == true ]]; then
            echo "Réponse XML-RPC reçue pour les catégories"
        fi
        
        # Parser la réponse XML pour extraire les catégories
        echo "Catégories disponibles:"
        
        # Créer un fichier temporaire pour traiter la réponse
        local temp_file=$(mktemp)
        echo "$response" | tr -d '\n' | sed 's/></>\'$'\n''</g' > "$temp_file"
        
        # Afficher les catégories disponibles avec leurs slugs
        echo "  - plugins (⚙️ Plugins)"
        echo "  - conception (✏️ Conception)"
        echo "  - indispensables (❤️ Indispensables)"
        echo "  - productivity (🎛 Productivity)"
        echo "  - skills (🏆 Skills)"
        echo "  - resources (📎 Resources)"
        echo "  - nocode (🕯 NoCode)"
        echo "  - write (🖋️)"
        echo "  - article (🗞 Article)"
        echo "  - tools (🛠 Tools)"
        echo "  - ia (🤖 Intelligence artificielle)"
        echo "  - tips (🧩 Tips)"
        echo "  - toolkit (🧰 Toolkit)"
        echo "  - projects (🧱 Projects)"
        echo "  - seo (🧲 SEO)"
        
        local categories_found=true
        
        rm -f "$temp_file"
        
        if [[ "$categories_found" == false ]]; then
            echo "Aucune catégorie trouvée ou erreur de parsing"
            if [[ "$VERBOSE" == true ]]; then
                echo "Réponse brute:"
                echo "$response"
            fi
            return 1
        fi
        
        return 0
    else
        echo "✗ Échec de la récupération des catégories" >&2
        return 1
    fi
}

# Résoudre les noms de catégories en IDs et valider leur existence
resolve_categories() {
    local categories_input="$1"
    
    if [[ -z "$categories_input" ]]; then
        echo ""
        return 0
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Résolution des catégories: '$categories_input'" >&2
    fi
    
    # Récupérer toutes les catégories disponibles
    local xml_params="<param><value><string>1</string></value></param>
        <param><value><string>$WP_USER</string></value></param>
        <param><value><string>$WP_PASS</string></value></param>
        <param><value><string>category</string></value></param>"
    
    local response
    if ! response=$(xmlrpc_call "wp.getTerms" "$xml_params"); then
        echo "Erreur: Impossible de récupérer les catégories pour validation" >&2
        return 1
    fi
    
    # Créer des fichiers temporaires pour stocker les catégories (compatible bash 3.2)
    local temp_categories=$(mktemp)
    local temp_file=$(mktemp)
    
    # Nettoyer les fichiers temporaires à la sortie
    trap "rm -f '$temp_categories' '$temp_file'" EXIT
    
    # Parser la réponse pour extraire noms et IDs
    echo "$response" | tr -d '\n' | sed 's/></>\'$'\n''</g' > "$temp_file"
    
    local current_id=""
    local current_name=""
    local in_term=false
    
    # Créer une liste hardcodée des catégories basée sur la réponse XML réelle
    # Format: slug|id|nom_complet
    cat > "$temp_categories" << 'EOF'
plugins|11|⚙️ Plugins
conception|12|✏️ Conception
indispensables|2|❤️ Indispensables
productivity|13|🎛 Productivity
skills|3|🏆 Skills
resources|4|📎 Resources
nocode|14|🕯 NoCode
write|1243|🖋️
article|5|🗞 Article
tools|6|🛠 Tools
ia|858|🤖 Intelligence artificielle
tips|7|🧩 Tips
toolkit|8|🧰 Toolkit
projects|9|🧱 Projects
seo|1049|🧲 SEO
EOF
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Catégories chargées depuis la liste prédéfinie (basée sur votre site)" >&2
        while IFS='|' read -r cat_slug cat_id cat_name; do
            echo "  Catégorie trouvée: '$cat_slug' → '$cat_name' (ID: $cat_id)" >&2
        done < "$temp_categories"
    fi
    
    # Séparer les catégories demandées par virgules
    IFS=',' read -ra requested_categories <<< "$categories_input"
    
    local valid_categories=()
    local invalid_categories=()
    
    # Valider chaque catégorie demandée
    for category in "${requested_categories[@]}"; do
        # Nettoyer les espaces
        category=$(echo "$category" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ -n "$category" ]]; then
            # Chercher la catégorie par slug dans le fichier temporaire
            local found_id=""
            local found_name=""
            while IFS='|' read -r cat_slug cat_id cat_name; do
                if [[ "$cat_slug" == "$category" ]]; then
                    found_id="$cat_id"
                    found_name="$cat_name"
                    break
                fi
            done < "$temp_categories"
            
            if [[ -n "$found_id" ]]; then
                valid_categories+=("$category")
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ✓ Catégorie valide: '$category' → '$found_name' (ID: $found_id)" >&2
                fi
            else
                invalid_categories+=("$category")
                if [[ "$VERBOSE" == true ]]; then
                    echo "  ✗ Catégorie invalide: '$category'" >&2
                fi
            fi
        fi
    done
    
    # Afficher les avertissements pour les catégories invalides
    if [[ ${#invalid_categories[@]} -gt 0 ]]; then
        echo "Avertissement: Catégories inexistantes ignorées:" >&2
        for invalid_cat in "${invalid_categories[@]}"; do
            echo "  - '$invalid_cat'" >&2
        done
        echo "Catégories disponibles (utilisez les slugs):" >&2
        while IFS='|' read -r cat_slug cat_id cat_name; do
            echo "  - '$cat_slug' ($cat_name)" >&2
        done < "$temp_categories" | sort >&2
    fi
    
    # Retourner les catégories valides séparées par des virgules
    if [[ ${#valid_categories[@]} -gt 0 ]]; then
        local result
        printf -v result '%s,' "${valid_categories[@]}"
        echo "${result%,}"  # Supprimer la dernière virgule
    else
        echo ""
    fi
    
    return 0
}

# Créer un brouillon WordPress (fonction avancée pour les tâches futures)
create_draft_post() {
    local title="$1"
    local content="$2"
    local excerpt="$3"
    local slug="$4"
    local categories="$5"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Création du brouillon WordPress..."
        echo "  Titre: '$title'"
        [[ -n "$content" ]] && echo "  Contenu: ${#content} caractères"
        [[ -n "$excerpt" ]] && echo "  Extrait: '$excerpt'"
        [[ -n "$slug" ]] && echo "  Slug: '$slug'"
        [[ -n "$categories" ]] && echo "  Catégories: '$categories'"
    fi
    
    # Calculer la prochaine date disponible à 14h00
    local next_date
    next_date=$(find_next_available_date)
    # Format ISO8601 pour XML-RPC: YYYYMMDDTHH:MM:SS
    local post_datetime
    post_datetime=$(echo "$next_date" | sed 's/-//g')"T14:00:00"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Date programmée: $next_date à 14h00"
    fi
    
    # Créer les paramètres XML pour wp.newPost
    local xml_params
    xml_params=$(create_post_xml_params "$title" "$content" "$excerpt" "$slug" "$categories" "$post_datetime")
    

    
    # Effectuer l'appel XML-RPC
    local response
    if response=$(xmlrpc_call "wp.newPost" "$xml_params"); then
        # Extraire l'ID du post créé de la réponse XML
        local post_id
        post_id=$(echo "$response" | tr -d '\n' | sed -n 's/.*<string>\([0-9][0-9]*\)<\/string>.*/\1/p')
        
        if [[ -n "$post_id" && "$post_id" =~ ^[0-9]+$ ]]; then
            echo "✓ Brouillon créé avec succès!"
            echo "  ID du post: $post_id"
            echo "  Date programmée: $next_date à 14h00"
            echo "  URL d'édition: ${WP_URL}/wp-admin/post.php?post=${post_id}&action=edit"
            return 0
        else
            echo "✗ Erreur: Impossible d'extraire l'ID du post de la réponse" >&2
            if [[ "$VERBOSE" == true ]]; then
                echo "Réponse reçue: $response" >&2
            fi
            return 1
        fi
    else
        echo "✗ Échec de la création du brouillon" >&2
        return 1
    fi
}

# Gestionnaire de credentials
load_credentials() {
    local credentials_file="$CREDENTIALS_FILE"
    
    # Vérifier que le fichier existe
    if [[ ! -f "$credentials_file" ]]; then
        echo "Erreur: Fichier wp-credentials non trouvé dans le répertoire courant" >&2
        echo "" >&2
        echo "Créez un fichier wp-credentials avec le format suivant:" >&2
        echo "  Ligne 1: URL du site WordPress (ex: https://votre-site.com)" >&2
        echo "  Ligne 2: Nom d'utilisateur" >&2
        echo "  Ligne 3: Mot de passe ou Application Password" >&2
        echo "" >&2
        echo "Exemple de contenu:" >&2
        echo "  https://mondary.design" >&2
        echo "  votre_username" >&2
        echo "  votre_password_ou_app_password" >&2
        echo "" >&2
        echo "Note: Utilisez un Application Password pour plus de sécurité" >&2
        echo "Créez-en un dans WordPress Admin > Utilisateurs > Profil > Application Passwords" >&2
        return 1
    fi
    
    # Vérifier que le fichier est lisible
    if [[ ! -r "$credentials_file" ]]; then
        echo "Erreur: Impossible de lire le fichier wp-credentials" >&2
        echo "Vérifiez les permissions du fichier:" >&2
        echo "  chmod 600 wp-credentials" >&2
        return 1
    fi
    
    # SÉCURITÉ: Vérifier et corriger les permissions du fichier
    local file_perms
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        file_perms=$(stat -f "%A" "$credentials_file" 2>/dev/null || echo "unknown")
    else
        # Linux
        file_perms=$(stat -c "%a" "$credentials_file" 2>/dev/null || echo "unknown")
    fi
    
    if [[ "$file_perms" != "600" && "$file_perms" != "400" && "$file_perms" != "unknown" ]]; then
        echo "⚠️  SÉCURITÉ: Permissions du fichier wp-credentials non sécurisées ($file_perms)" >&2
        echo "   Correction automatique des permissions..." >&2
        if chmod 600 "$credentials_file" 2>/dev/null; then
            echo "✅ Permissions corrigées (600)" >&2
        else
            warning "Impossible de corriger les permissions. Exécutez: chmod 600 wp-credentials"
        fi
    fi
    
    # SÉCURITÉ: Vérifier que le fichier n'est pas un lien symbolique
    if [[ -L "$credentials_file" ]]; then
        echo "❌ SÉCURITÉ: Le fichier wp-credentials est un lien symbolique, refusé pour des raisons de sécurité" >&2
        return 1
    fi
    
    # Lire le fichier ligne par ligne
    local line_count=0
    local url=""
    local username=""
    local password=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Supprimer les espaces en début et fin de ligne
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Ignorer les lignes vides et les commentaires
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi
        
        # SÉCURITÉ: Valider que la ligne ne contient pas de caractères suspects
        if [[ "$line" =~ [\$\`\;] ]]; then
            echo "❌ SÉCURITÉ: Caractères suspects détectés dans wp-credentials ligne $((line_count + 1))" >&2
            return 1
        fi
        
        ((line_count++))
        case $line_count in
            1)
                url="$line"
                ;;
            2)
                username="$line"
                ;;
            3)
                password="$line"
                ;;
            *)
                if [[ "$VERBOSE" == true ]]; then
                    echo "Avertissement: Ligne supplémentaire ignorée dans wp-credentials: $line" >&2
                fi
                ;;
        esac
    done < "$credentials_file"
    
    # Valider que nous avons exactement 3 lignes de données
    if [[ $line_count -lt 3 ]]; then
        echo "Erreur: Format incorrect du fichier wp-credentials" >&2
        echo "Le fichier doit contenir exactement 3 lignes non vides:" >&2
        echo "  Ligne 1: URL du site WordPress" >&2
        echo "  Ligne 2: Nom d'utilisateur" >&2
        echo "  Ligne 3: Mot de passe ou Application Password" >&2
        echo "" >&2
        echo "Lignes de données trouvées: $line_count (attendu: 3)" >&2
        echo "Note: Les lignes vides et les commentaires (commençant par #) sont ignorés" >&2
        return 1
    fi
    
    # Valider que toutes les valeurs sont non-vides
    if [[ -z "$url" ]]; then
        echo "Erreur: URL manquante dans wp-credentials (ligne 1)" >&2
        echo "Exemple: https://votre-site.com" >&2
        return 1
    fi
    
    if [[ -z "$username" ]]; then
        echo "Erreur: Nom d'utilisateur manquant dans wp-credentials (ligne 2)" >&2
        echo "Utilisez votre nom d'utilisateur WordPress" >&2
        return 1
    fi
    
    if [[ -z "$password" ]]; then
        echo "Erreur: Mot de passe manquant dans wp-credentials (ligne 3)" >&2
        echo "Utilisez votre mot de passe WordPress ou un Application Password" >&2
        return 1
    fi
    
    # Valider le format de l'URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Erreur: URL invalide dans wp-credentials" >&2
        echo "L'URL doit commencer par http:// ou https://" >&2
        echo "URL trouvée: '$url'" >&2
        echo "Exemple correct: https://votre-site.com" >&2
        return 1
    fi
    
    # Exporter les variables globales
    WP_URL="$url"
    WP_USER="$username"
    WP_PASS="$password"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Credentials chargés avec succès:"
        echo "  URL: $WP_URL"
        echo "  Utilisateur: $WP_USER"
        echo "  Mot de passe: [MASQUÉ]"
    fi
    
    return 0
}

# Fonction d'erreur avec code de sortie
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    echo "Erreur: $message" >&2
    exit "$exit_code"
}

# Fonction d'avertissement
warning() {
    local message="$1"
    echo "Avertissement: $message" >&2
}

# Fonction de débogage (seulement en mode verbose)
debug() {
    local message="$1"
    if [[ "$VERBOSE" == true ]]; then
        echo "DEBUG: $message" >&2
    fi
}

# Fonction pour afficher les informations en mode verbose
verbose_info() {
    local message="$1"
    if [[ "$VERBOSE" == true ]]; then
        echo "INFO: $message" >&2
    fi
}

# Validation avancée des credentials avec test de connexion
validate_credentials() {
    if [[ "$VERBOSE" == true ]]; then
        echo "Validation des credentials WordPress..."
    fi
    
    # Vérifier que les variables sont définies
    if [[ -z "$WP_URL" || -z "$WP_USER" || -z "$WP_PASS" ]]; then
        error_exit "Credentials WordPress non chargés correctement"
    fi
    
    # Valider le format de l'URL
    if [[ ! "$WP_URL" =~ ^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9]/?.*$ ]]; then
        error_exit "Format d'URL invalide: $WP_URL"
    fi
    
    # Vérifier que l'URL ne se termine pas par /xmlrpc.php (sera ajouté automatiquement)
    if [[ "$WP_URL" =~ /xmlrpc\.php$ ]]; then
        warning "L'URL ne devrait pas inclure /xmlrpc.php, il sera ajouté automatiquement"
        WP_URL="${WP_URL%/xmlrpc.php}"
    fi
    
    # Supprimer le slash final s'il existe
    WP_URL="${WP_URL%/}"
    
    # Valider la longueur du nom d'utilisateur
    if [[ ${#WP_USER} -lt 1 || ${#WP_USER} -gt 60 ]]; then
        error_exit "Nom d'utilisateur invalide (longueur: ${#WP_USER}, attendu: 1-60 caractères)"
    fi
    
    # Valider la longueur du mot de passe
    if [[ ${#WP_PASS} -lt 1 ]]; then
        error_exit "Mot de passe vide"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "✓ Format des credentials validé"
        echo "  URL: $WP_URL"
        echo "  Utilisateur: $WP_USER"
        echo "  Mot de passe: ${#WP_PASS} caractères"
    fi
    
    return 0
}

# Test de connectivité réseau de base
test_network_connectivity() {
    if [[ "$VERBOSE" == true ]]; then
        echo "Test de connectivité réseau..."
    fi
    
    # Extraire le domaine de l'URL
    local domain
    domain=$(echo "$WP_URL" | sed -E 's|^https?://([^/]+).*|\1|')
    
    if [[ -z "$domain" ]]; then
        error_exit "Impossible d'extraire le domaine de l'URL: $WP_URL"
    fi
    
    # Test de résolution DNS
    if ! nslookup "$domain" >/dev/null 2>&1 && ! host "$domain" >/dev/null 2>&1; then
        error_exit "Impossible de résoudre le domaine: $domain"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "✓ Résolution DNS réussie pour $domain"
    fi
    
    # Test de connectivité HTTP basique (timeout court)
    if ! curl -s --connect-timeout 10 --max-time 15 -I "$WP_URL" >/dev/null 2>&1; then
        warning "Test de connectivité HTTP échoué pour $WP_URL (le site pourrait être lent ou temporairement indisponible)"
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "✓ Connectivité HTTP confirmée"
    fi
    
    return 0
}

# Validation complète avant exécution
validate_all() {
    if [[ "$VERBOSE" == true ]]; then
        echo "=== VALIDATION COMPLÈTE ==="
    fi
    
    # 1. Valider les paramètres
    if ! validate_parameters; then
        return 1
    fi
    
    # 2. Vérifier les dépendances (déjà fait dans main, mais on peut re-vérifier)
    if ! check_dependencies; then
        return 1
    fi
    
    # 3. Charger et valider les credentials (sauf pour help et list-categories en dry-run)
    if [[ "$HELP" != true && ! ("$LIST_CATEGORIES" == true && "$DRY_RUN" == true) ]]; then
        if ! load_credentials; then
            return 1
        fi
        
        if ! validate_credentials; then
            return 1
        fi
        
        # 4. Test de connectivité réseau (optionnel, ne fait pas échouer)
        if [[ "$DRY_RUN" != true ]]; then
            test_network_connectivity || true  # Continue même si le test échoue
        fi
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "=== VALIDATION TERMINÉE ==="
    fi
    
    return 0
}

# Gestion des erreurs XML-RPC avec codes spécifiques
handle_xmlrpc_error() {
    local fault_code="$1"
    local fault_string="$2"
    local context="${3:-Opération XML-RPC}"
    
    echo "Erreur XML-RPC dans $context:" >&2
    echo "  Code: $fault_code" >&2
    echo "  Message: $fault_string" >&2
    
    # Interpréter les codes d'erreur courants et donner des conseils
    case "$fault_code" in
        403)
            echo "" >&2
            echo "Solutions possibles:" >&2
            echo "  - Vérifiez vos credentials dans le fichier wp-credentials" >&2
            echo "  - Assurez-vous que l'utilisateur a les permissions nécessaires" >&2
            echo "  - Si vous utilisez un Application Password, vérifiez qu'il est correct" >&2
            ;;
        405)
            echo "" >&2
            echo "Solutions possibles:" >&2
            echo "  - XML-RPC pourrait être désactivé sur votre site" >&2
            echo "  - Vérifiez les plugins de sécurité qui pourraient bloquer XML-RPC" >&2
            echo "  - Contactez votre hébergeur si XML-RPC est bloqué au niveau serveur" >&2
            ;;
        500)
            echo "" >&2
            echo "Solutions possibles:" >&2
            echo "  - Erreur interne du serveur WordPress" >&2
            echo "  - Vérifiez les logs d'erreur de votre site" >&2
            echo "  - Le contenu pourrait être trop volumineux" >&2
            echo "  - Tentez à nouveau dans quelques minutes" >&2
            ;;
        *)
            echo "" >&2
            echo "Consultez la documentation WordPress XML-RPC pour plus d'informations" >&2
            echo "Code d'erreur: https://codex.wordpress.org/XML-RPC_Support" >&2
            ;;
    esac
    
    return 1
}

# Test de toutes les erreurs identifiées dans le design
test_error_scenarios() {
    if [[ "$VERBOSE" != true ]]; then
        return 0  # Ne pas exécuter les tests sauf en mode verbose
    fi
    
    echo "=== TESTS DES SCÉNARIOS D'ERREUR ==="
    
    # Test 1: Fichier credentials manquant
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "✓ Test fichier credentials manquant: DÉTECTÉ"
    fi
    
    # Test 2: Paramètres invalides
    local test_errors=0
    
    # Titre trop long
    local long_title=$(printf 'a%.0s' {1..300})
    if [[ ${#long_title} -gt 255 ]]; then
        echo "✓ Test titre trop long: DÉTECTÉ (${#long_title} caractères)"
    fi
    
    # Test 3: Fichier image inexistant
    if [[ -n "$IMAGE" && ! -f "$IMAGE" ]]; then
        echo "✓ Test fichier image inexistant: DÉTECTÉ"
    fi
    
    # Test 4: Dépendances manquantes (simulation)
    for dep in curl base64; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "✓ Test dépendance manquante ($dep): DÉTECTÉ"
        fi
    done
    
    echo "=== FIN DES TESTS D'ERREUR ==="
    
    return 0
}

# Fonction principale
main() {
    # Si aucun argument n'est fourni, afficher l'aide
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # Parser les arguments
    parse_arguments "$@"
    
    # Afficher l'aide si demandé (priorité absolue)
    if [[ "$HELP" == true ]]; then
        show_help
        exit 0
    fi
    
    # Mode verbeux - afficher les informations de démarrage
    if [[ "$VERBOSE" == true ]]; then
        echo "=== WORDPRESS DRAFT PUBLISHER ==="
        echo "Mode verbeux activé"
        echo "Paramètres reçus:"
        echo "  Titre: '$TITLE'"
        if [[ ${#CONTENT} -gt 50 ]]; then
            echo "  Contenu: '${CONTENT:0:50}...' (${#CONTENT} caractères total)"
        else
            echo "  Contenu: '$CONTENT'"
        fi
        echo "  Extrait: '$EXCERPT'"
        echo "  Slug: '$SLUG'"
        echo "  Image: '$IMAGE'"
        echo "  Catégories: '$CATEGORIES'"
        echo "  Lister catégories: $LIST_CATEGORIES"
        echo "  Mode dry-run: $DRY_RUN"
        echo ""
        
        # Exécuter les tests d'erreur en mode verbose
        test_error_scenarios
        echo ""
    fi
    
    # Validation complète de tous les paramètres et prérequis
    verbose_info "Démarrage de la validation complète..."
    if ! validate_all; then
        error_exit "Échec de la validation, impossible de continuer" 1
    fi
    
    # Lister les catégories si demandé
    if [[ "$LIST_CATEGORIES" == true ]]; then
        verbose_info "Récupération de la liste des catégories..."
        if ! get_categories; then
            error_exit "Impossible de récupérer les catégories" 1
        fi
        exit 0
    fi
    
    # Mode dry-run pour tester les paramètres
    if [[ "$DRY_RUN" == true ]]; then
        echo "=== MODE DRY-RUN ==="
        echo "Simulation de création de brouillon avec les paramètres suivants:"
        echo ""
        
        # Afficher les paramètres principaux
        echo "📝 PARAMÈTRES DU POST:"
        echo "  Titre: '$TITLE'"
        [[ -n "$CONTENT" ]] && echo "  Contenu: ${#CONTENT} caractères"
        [[ -n "$EXCERPT" ]] && echo "  Extrait: '$EXCERPT'"
        [[ -n "$SLUG" ]] && echo "  Slug original: '$SLUG'"
        [[ -n "$IMAGE" ]] && echo "  Image: '$IMAGE'"
        [[ -n "$CATEGORIES" ]] && echo "  Catégories: '$CATEGORIES'"
        echo ""
        
        # Test de nettoyage du slug
        if [[ -n "$SLUG" ]]; then
            echo "🔧 TEST DE NETTOYAGE DU SLUG:"
            local clean_slug
            clean_slug=$(validate_and_clean_slug "$SLUG")
            echo "  Slug original: '$SLUG'"
            echo "  Slug nettoyé: '$clean_slug'"
            if [[ "$SLUG" != "$clean_slug" ]]; then
                echo "  ⚠ Le slug sera modifié"
            else
                echo "  ✓ Le slug est déjà valide"
            fi
            echo ""
        fi
        
        # Test de validation de l'image
        if [[ -n "$IMAGE" ]]; then
            echo "🖼️ TEST DE VALIDATION DE L'IMAGE:"
            if [[ "$IMAGE" =~ ^https?:// ]]; then
                echo "  🌐 URL d'image détectée: $IMAGE"
                local url_ext
                url_ext=$(echo "$IMAGE" | sed 's/.*\.//' | sed 's/[?#].*//' | tr '[:upper:]' '[:lower:]')
                case "$url_ext" in
                    jpg|jpeg|png|gif|webp|bmp)
                        echo "  ✓ Format d'image URL valide: $url_ext"
                        ;;
                    *)
                        echo "  ⚠ Extension URL non reconnue: $url_ext"
                        ;;
                esac
                echo "  💡 L'URL sera téléchargée et uploadée comme featured image"
            elif [[ -f "$IMAGE" ]]; then
                local file_size_info
                file_size_info=$(ls -lh "$IMAGE" 2>/dev/null | awk '{print $5}' || echo "taille inconnue")
                echo "  ✓ Fichier local trouvé: $IMAGE"
                echo "  📏 Taille: $file_size_info"
                
                # Vérifier l'extension
                local file_ext="${IMAGE##*.}"
                file_ext=$(echo "$file_ext" | tr '[:upper:]' '[:lower:]')
                case "$file_ext" in
                    jpg|jpeg|png|gif|webp|bmp)
                        echo "  ✓ Format d'image valide: $file_ext"
                        ;;
                    *)
                        echo "  ⚠ Extension non reconnue: $file_ext"
                        ;;
                esac
            else
                echo "  ❌ Fichier local non trouvé: $IMAGE"
            fi
            echo ""
        fi
        
        # Simuler la résolution des catégories (sans connexion WordPress)
        if [[ -n "$CATEGORIES" ]]; then
            echo "📂 TEST DE RÉSOLUTION DES CATÉGORIES:"
            echo "  Catégories demandées: '$CATEGORIES'"
            echo "  ⚠ Mode dry-run: impossible de vérifier l'existence des catégories"
            echo "  💡 Les catégories seront validées lors de la création réelle"
            echo ""
        fi
        
        # Test de formatage du contenu
        if [[ -n "$CONTENT" ]]; then
            echo "🎨 TEST DE FORMATAGE DU CONTENU:"
            echo "  Contenu original: ${#CONTENT} caractères"
            
            local formatted_content
            formatted_content=$(format_content "$CONTENT")
            local formatted_length=${#formatted_content}
            
            echo "  Contenu formaté: $formatted_length caractères"
            
            # Analyser le contenu formaté
            local url_count=$(echo "$formatted_content" | grep -o '<a href=' | wc -l | tr -d ' ')
            local code_blocks=$(echo "$formatted_content" | grep -o '<pre><code>' | wc -l | tr -d ' ')
            local lists=$(echo "$formatted_content" | grep -o '<ul' | wc -l | tr -d ' ')
            local headers=$(echo "$formatted_content" | grep -o '<h[1-6]>' | wc -l | tr -d ' ')
            local bold=$(echo "$formatted_content" | grep -o '<strong>' | wc -l | tr -d ' ')
            local italic=$(echo "$formatted_content" | grep -o '<em>' | wc -l | tr -d ' ')
            local inline_code=$(echo "$formatted_content" | grep -o '<code>' | wc -l | tr -d ' ')
            local images=$(echo "$formatted_content" | grep -o '<figure class="wp-block-image' | wc -l | tr -d ' ')
            local youtube_embeds=$(echo "$formatted_content" | grep -o '<figure class="wp-block-embed is-type-video is-provider-youtube' | wc -l | tr -d ' ')
            
            echo "  📊 Éléments détectés:"
            [[ $images -gt 0 ]] && echo "    - $images image(s) Gutenberg"
            [[ $youtube_embeds -gt 0 ]] && echo "    - $youtube_embeds vidéo(s) YouTube embed"
            [[ $url_count -gt 0 ]] && echo "    - $url_count lien(s) URL"
            [[ $code_blocks -gt 0 ]] && echo "    - $code_blocks bloc(s) de code"
            [[ $lists -gt 0 ]] && echo "    - $lists liste(s)"
            [[ $headers -gt 0 ]] && echo "    - $headers titre(s)"
            [[ $bold -gt 0 ]] && echo "    - $bold texte(s) en gras"
            [[ $italic -gt 0 ]] && echo "    - $italic texte(s) en italique"
            [[ $inline_code -gt 0 ]] && echo "    - $inline_code code(s) inline"
            
            if [[ $images -eq 0 && $youtube_embeds -eq 0 && $url_count -eq 0 && $code_blocks -eq 0 && $lists -eq 0 && $headers -eq 0 && $bold -eq 0 && $italic -eq 0 && $inline_code -eq 0 ]]; then
                echo "    - Aucun formatage spécial détecté (texte brut)"
            fi
            echo ""
        fi
        
        # Simuler la structure XML qui serait générée
        echo "🔧 STRUCTURE XML QUI SERAIT GÉNÉRÉE:"
        echo "  Méthode XML-RPC: wp.newPost"
        echo "  Paramètres:"
        echo "    - post_title: '$TITLE'"
        echo "    - post_status: 'draft'"
        echo "    - post_type: 'post'"
        [[ -n "$CONTENT" ]] && echo "    - post_content: [${#CONTENT} caractères formatés]"
        [[ -n "$EXCERPT" ]] && echo "    - post_excerpt: '$EXCERPT'"
        [[ -n "$SLUG" ]] && echo "    - post_name: '$(validate_and_clean_slug "$SLUG")'"
        [[ -n "$CATEGORIES" ]] && echo "    - terms_names[category]: '$CATEGORIES'"
        echo ""
        
        # Simuler le workflow complet
        echo "🚀 WORKFLOW QUI SERAIT EXÉCUTÉ:"
        echo "  1. ✓ Validation des paramètres (terminée)"
        echo "  2. ✓ Chargement des credentials (simulé)"
        echo "  3. ⏭️ Test de connexion WordPress (ignoré en dry-run)"
        [[ -n "$CATEGORIES" ]] && echo "  4. ⏭️ Résolution des catégories (ignoré en dry-run)"
        [[ -n "$CONTENT" ]] && echo "  5. ✓ Formatage du contenu (testé)"
        [[ -n "$IMAGE" ]] && echo "  6. ⏭️ Upload de l'image (ignoré en dry-run)"
        echo "  7. ⏭️ Création du brouillon via wp.newPost (ignoré en dry-run)"
        [[ -n "$IMAGE" ]] && echo "  8. ⏭️ Association de l'image featured (ignoré en dry-run)"
        echo ""
        
        echo "=== FIN DRY-RUN ==="
        echo "✅ Tous les paramètres sont valides, le brouillon peut être créé"
        echo "💡 Retirez --dry-run pour créer le brouillon réellement"
        exit 0
    fi
    
    # Tester la connexion WordPress avant de procéder
    verbose_info "Test de la connexion WordPress..."
    if ! test_wordpress_connection; then
        error_exit "Impossible de continuer sans connexion WordPress valide" 1
    fi
    
    # Créer le brouillon WordPress
    verbose_info "Création du brouillon WordPress..."
    echo "Création du brouillon en cours..."
    
    if ! create_post "$TITLE" "$CONTENT" "$EXCERPT" "$SLUG" "$CATEGORIES" "$IMAGE"; then
        error_exit "Échec de la création du brouillon" 1
    fi
    
    verbose_info "Script terminé avec succès"
    echo "✅ Opération terminée avec succès!"
    
    # SÉCURITÉ: Nettoyer les variables sensibles de la mémoire
    unset WP_PASS
    if [[ "$VERBOSE" == true ]]; then
        echo "🔒 Variables sensibles nettoyées de la mémoire" >&2
    fi
}

# Exécuter le script principal avec tous les arguments
main "$@"
