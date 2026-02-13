#!/bin/bash
# Author: cmondary - https://github.com/mondary
set -euo pipefail

# Load WordPress secrets from a single credentials file.
# Shared by all scripts in this folder.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="${WP_CLI_OLD_CONFIG_FILE:-$SCRIPT_DIR/../secrets/wp-credentials}"

if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "Missing credentials file: $CREDENTIALS_FILE"
  exit 1
fi

WP_SITE_URL="$(sed -n '1p' "$CREDENTIALS_FILE" | tr -d '\r')"
WP_USERNAME="$(sed -n '2p' "$CREDENTIALS_FILE" | tr -d '\r')"
WP_APP_PASSWORD="$(sed -n '3p' "$CREDENTIALS_FILE" | tr -d '\r')"

if [ -z "$WP_SITE_URL" ] || [ -z "$WP_USERNAME" ] || [ -z "$WP_APP_PASSWORD" ]; then
  echo "Invalid credentials file: $CREDENTIALS_FILE"
  echo "Expected 3 lines: site_url, username, app_password"
  exit 1
fi

export WP_SITE_URL
export WP_USERNAME
export WP_APP_PASSWORD
