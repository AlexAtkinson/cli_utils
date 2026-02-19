#!/usr/bin/env bash

set -euo pipefail

DEFAULT_INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin"
DEFAULT_MAN_DIR="/usr/local/share/man/man1"
LOCAL_MAN_DIR="$HOME/.local/share/man/man1"

echo "This script uninstalls the 'dts' utility and its man page."
echo

if [[ -d "$LOCAL_BIN_DIR" && ":$PATH:" == *":$LOCAL_BIN_DIR:"* ]]; then
  DEFAULT_INSTALL_DIR="$LOCAL_BIN_DIR"
  DEFAULT_MAN_DIR="$LOCAL_MAN_DIR"
fi

read -r -p "Remove binary from (default: $DEFAULT_INSTALL_DIR): " USER_INSTALL_DIR
INSTALL_DIR="${USER_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

read -r -p "Remove man page from (default: $DEFAULT_MAN_DIR): " USER_MAN_DIR
MAN_DIR="${USER_MAN_DIR:-$DEFAULT_MAN_DIR}"

BINARY_PATH="$INSTALL_DIR/dts"
MAN_PATH="$MAN_DIR/dts.1"

echo
if [[ -e "$BINARY_PATH" ]]; then
  rm -f "$BINARY_PATH"
  echo "Removed binary: $BINARY_PATH"
else
  echo "Binary not found (already absent): $BINARY_PATH"
fi

if [[ -e "$MAN_PATH" ]]; then
  rm -f "$MAN_PATH"
  echo "Removed man page: $MAN_PATH"
else
  echo "Man page not found (already absent): $MAN_PATH"
fi

echo
echo "dts uninstall complete."

if command -v mandb >/dev/null 2>&1; then
  echo "Tip: run 'mandb' (possibly with sudo) to refresh man page indexes."
fi
