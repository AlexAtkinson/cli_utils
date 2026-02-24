#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin"
DEFAULT_MAN_DIR="/usr/local/share/man/man1"
LOCAL_MAN_DIR="$HOME/.local/share/man/man1"

echo "This script installs the 'md-add-copyright' utility and its man page."
echo

if [[ -d "$LOCAL_BIN_DIR" && ":$PATH:" == *":$LOCAL_BIN_DIR:"* ]]; then
  DEFAULT_INSTALL_DIR="$LOCAL_BIN_DIR"
  DEFAULT_MAN_DIR="$LOCAL_MAN_DIR"
fi

read -r -p "Install script to (default: $DEFAULT_INSTALL_DIR): " USER_INSTALL_DIR
INSTALL_DIR="${USER_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

read -r -p "Install man page to (default: $DEFAULT_MAN_DIR): " USER_MAN_DIR
MAN_DIR="${USER_MAN_DIR:-$DEFAULT_MAN_DIR}"

echo
echo "Installing script to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/md-add-copyright" "$INSTALL_DIR/md-add-copyright"
chmod +x "$INSTALL_DIR/md-add-copyright"

echo "Installing man page to $MAN_DIR..."
mkdir -p "$MAN_DIR"
cp "$SCRIPT_DIR/md-add-copyright.1" "$MAN_DIR/md-add-copyright.1"

echo
echo "md-add-copyright installed successfully."

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Warning: '$INSTALL_DIR' is not currently in your PATH."
  echo "Add it in your shell config, for example:"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

if command -v mandb >/dev/null 2>&1; then
  echo "Tip: run 'mandb' (possibly with sudo) if 'man md-add-copyright' is not immediately found."
fi
