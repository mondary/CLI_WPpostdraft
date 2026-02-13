#!/bin/bash

# Versioning Helper Script
# Usage: ./archive_version.sh v3

if [ -z "$1" ]; then
    echo "Usage: $0 <version_number>"
    echo "Example: $0 v3"
    echo ""
    echo "This will copy wp_post_draft.sh to wp_post_draft_v3.sh"
    exit 1
fi

VERSION="$1"
ARCHIVE_FILE="wp_post_draft_${VERSION}.sh"

if [ -f "$ARCHIVE_FILE" ]; then
    echo "Error: $ARCHIVE_FILE already exists!"
    exit 1
fi

cp wp_post_draft.sh "$ARCHIVE_FILE"
echo "✅ Archived current version as: $ARCHIVE_FILE"
echo ""
echo "Current versions:"
ls -1 wp_post_draft*.sh | sort -V