#!/bin/bash

echo "=== WordPress Draft Poster - Usage Demo ==="
echo ""

echo "1. Setup configuration (saves credentials, no post creation):"
echo "   ./wp_post_draft.sh --config mysite.conf"
echo ""

echo "2. Use configuration to create posts:"
echo "   ./wp_post_draft.sh --load-config mysite.conf"
echo ""

echo "3. Interactive mode (no config file):"
echo "   ./wp_post_draft.sh"
echo ""

echo "4. Show help:"
echo "   ./wp_post_draft.sh --help"
echo ""

echo "5. Environment variable setup:"
echo "   ./wp_post_draft.sh --export"
echo ""

echo "=== Current configuration files ==="
echo ""
if [ -f "mysite.conf" ]; then
    echo "✓ mysite.conf - Created and ready to use"
    echo "  Contains: $(grep WP_USERNAME mysite.conf | cut -d'"' -f2)"
else
    echo "✗ mysite.conf - Not found"
fi

if [ -f "sample_config.conf" ]; then
    echo "✓ sample_config.conf - Available"
else
    echo "✗ sample_config.conf - Not found"
fi

echo ""
echo "=== Security Note ==="
echo "Config files contain passwords in plain text."
echo "File permissions are automatically set to 600 (owner read/write only)."
echo ""
ls -la *.conf 2>/dev/null || echo "No .conf files found"