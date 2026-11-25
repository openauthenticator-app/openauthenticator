#!/bin/bash

set -e

POLICY_ID="polkit.app.openauthenticator"
POLICY_FILENAME="${POLICY_ID}.policy"
POLICY_DEST_PATH="/usr/share/polkit-1/actions/${POLICY_FILENAME}"

LOCALES=("fr" "de" "it" "pt" "es")

# Check root
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  This script must be run as root (sudo)."
  exit 1
fi

# Remove the policy file if it exists
if [[ -f "$POLICY_DEST_PATH" ]]; then
  echo "🗑️  Removing policy file..."
  rm "$POLICY_DEST_PATH"
  echo "✅ Policy file removed from $POLICY_DEST_PATH"
else
  echo "ℹ️  No policy file found at $POLICY_DEST_PATH"
fi

# Removing translations
echo "🌐 Removing translations..."
for LOCALE in "${LOCALES[@]}"; do
  MO_DIR="/usr/share/locale/${LOCALE}/LC_MESSAGES"
  MO_FILE="${MO_DIR}/${POLICY_ID}.mo"
  
  if [[ -f "$MO_FILE" ]]; then
    echo "🗑️  Removing translation file at $MO_FILE..."
    rm "$MO_FILE"
    echo "✅ Translation file removed from $MO_DIR"
  else
    echo "ℹ️  No translation file found at $MO_FILE"
  fi
done

# Restart polkit to apply changes
echo "🔄 Restarting polkit..."
systemctl restart polkit

echo "✅ Uninstall complete."

