#!/bin/bash
set -euo pipefail

# Legacy wrapper kept for backward compatibility.
# Prefer: ./wp-post-rest-title-content.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/wp-post-rest-title-content.sh" "$@"
