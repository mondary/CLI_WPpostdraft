#!/bin/bash
# Author: cmondary - https://github.com/mondary

# Test script for the enhanced validate_image_url function
# Extract just the function we need to test

# Enable verbose mode for testing
VERBOSE=true

# Copy the validate_image_url function here for testing
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
    
    # Simple test - just check if we can reach the URL
    local http_code
    local curl_exit_code
    
    http_code=$(curl -s -w "%{http_code}" \
        -H "User-Agent: wp-draft.sh/1.0 (WordPress Draft Publisher)" \
        --connect-timeout 10 \
        --max-time 15 \
        --head \
        -o /dev/null \
        "$image_url")
    
    curl_exit_code=$?
    
    if [[ "$VERBOSE" == true ]]; then
        echo "  Code HTTP: $http_code"
        echo "  Code de sortie curl: $curl_exit_code"
    fi
    
    # Basic validation
    if [[ $curl_exit_code -ne 0 ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "  Erreur: Impossible d'accéder à l'URL" >&2
        fi
        return 1
    fi
    
    case $http_code in
        200)
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ URL accessible (HTTP 200)"
            fi
            return 0
            ;;
        *)
            if [[ "$VERBOSE" == true ]]; then
                echo "  Erreur: Code HTTP: $http_code" >&2
            fi
            return 1
            ;;
    esac
}

echo "=== Test de validation d'URL d'image ==="
echo

# Test 1: URL valide avec image JPEG
echo "Test 1: URL JPEG valide"
if validate_image_url "https://httpbin.org/image/jpeg"; then
    echo "✓ Test 1 réussi"
else
    echo "✗ Test 1 échoué"
fi
echo

# Test 2: URL invalide (404)
echo "Test 2: URL 404"
if validate_image_url "https://httpbin.org/status/404"; then
    echo "✗ Test 2 échoué (devrait échouer)"
else
    echo "✓ Test 2 réussi (échec attendu)"
fi
echo

# Test 3: URL avec format invalide
echo "Test 3: Format d'URL invalide"
if validate_image_url "not-a-url"; then
    echo "✗ Test 3 échoué (devrait échouer)"
else
    echo "✓ Test 3 réussi (échec attendu)"
fi
echo

# Test 4: URL vide
echo "Test 4: URL vide"
if validate_image_url ""; then
    echo "✗ Test 4 échoué (devrait échouer)"
else
    echo "✓ Test 4 réussi (échec attendu)"
fi
echo

echo "=== Tests terminés ==="
