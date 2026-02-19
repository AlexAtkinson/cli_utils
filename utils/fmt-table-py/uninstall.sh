#!/usr/bin/env bash

set -euo pipefail

DEFAULT_INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin"

echo "This script uninstalls the 'fmt-table' utility."
echo

if [[ -d "$LOCAL_BIN_DIR" && ":$PATH:" == *":$LOCAL_BIN_DIR:"* ]]; then
  DEFAULT_INSTALL_DIR="$LOCAL_BIN_DIR"
fi

read -r -p "Remove binary from (default: $DEFAULT_INSTALL_DIR): " USER_INSTALL_DIR
INSTALL_DIR="${USER_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

BINARY_PATH="$INSTALL_DIR/fmt-table"

echo
if [[ -e "$BINARY_PATH" ]]; then
  rm -f "$BINARY_PATH"
  echo "Removed binary: $BINARY_PATH"
else
  echo "Binary not found (already absent): $BINARY_PATH"
fi

echo
echo "fmt-table uninstall complete."
