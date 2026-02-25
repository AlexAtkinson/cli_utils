#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin"
DEFAULT_MAN_DIR="/usr/local/share/man/man1"
LOCAL_MAN_DIR="$HOME/.local/share/man/man1"
GLOBAL_INSTALL=false
INTERACTIVE=false

if [[ "$-" =~ i || -t 0 ]]; then
  INTERACTIVE=true
fi

for arg in "$@"; do
  case "$arg" in
    --global)
      GLOBAL_INSTALL=true
      ;;
    -h|--help)
      echo "Usage: ${0##*/} [--global]"
      echo
      echo "  --global   Use global defaults (/usr/local/bin and /usr/local/share/man/man1)"
      exit 0
      ;;
    *)
      echo "Error: unknown option '$arg'" >&2
      echo "Try: ${0##*/} --help" >&2
      exit 2
      ;;
  esac
done

ET_DIR="$SCRIPT_DIR/et"
RC_DIR="$SCRIPT_DIR/rc"
LOGGERX_DIR="$SCRIPT_DIR/loggerx"

echo "This script installs et, rc, and loggerx (plus their man pages)."
echo

if [[ "$GLOBAL_INSTALL" != "true" && "$INTERACTIVE" == "true" ]]; then
  read -r -p "Install globally for all users? [y/N]: " USER_GLOBAL_INSTALL
  if [[ "$USER_GLOBAL_INSTALL" =~ ^([yY]|[yY][eE][sS])$ ]]; then
    GLOBAL_INSTALL=true
  fi
fi

if [[ "$GLOBAL_INSTALL" != "true" ]]; then
  if [[ -d "$LOCAL_BIN_DIR" && ":$PATH:" == *":$LOCAL_BIN_DIR:"* ]]; then
    DEFAULT_INSTALL_DIR="$LOCAL_BIN_DIR"
    DEFAULT_MAN_DIR="$LOCAL_MAN_DIR"
  fi
fi

if [[ "$GLOBAL_INSTALL" == "true" || "$INTERACTIVE" != "true" ]]; then
  INSTALL_DIR="$DEFAULT_INSTALL_DIR"
  MAN_DIR="$DEFAULT_MAN_DIR"
else
  read -r -p "Install binaries to (default: $DEFAULT_INSTALL_DIR): " USER_INSTALL_DIR
  INSTALL_DIR="${USER_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

  read -r -p "Install man pages to (default: $DEFAULT_MAN_DIR): " USER_MAN_DIR
  MAN_DIR="${USER_MAN_DIR:-$DEFAULT_MAN_DIR}"
fi

SUDO_CMD=()
if [[ "$GLOBAL_INSTALL" == "true" && "$EUID" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD=(sudo)
  else
    echo "Error: --global install requires root privileges or 'sudo'." >&2
    exit 1
  fi
fi

echo
for dir in "$ET_DIR" "$RC_DIR" "$LOGGERX_DIR"; do
  if [[ ! -d "$dir" ]]; then
    echo "Error: expected utility directory missing: $dir" >&2
    exit 1
  fi
done

echo "Building et..."
go build -o "$ET_DIR/et" "$ET_DIR/main.go"

echo "Building rc..."
go build -o "$RC_DIR/rc" "$RC_DIR/main.go"

echo "Building loggerx..."
go build -o "$LOGGERX_DIR/loggerx" "$LOGGERX_DIR/main.go"

echo "Installing binaries to $INSTALL_DIR..."
"${SUDO_CMD[@]}" mkdir -p "$INSTALL_DIR"
"${SUDO_CMD[@]}" cp "$ET_DIR/et" "$INSTALL_DIR/et"
"${SUDO_CMD[@]}" cp "$RC_DIR/rc" "$INSTALL_DIR/rc"
"${SUDO_CMD[@]}" cp "$LOGGERX_DIR/loggerx" "$INSTALL_DIR/loggerx"
"${SUDO_CMD[@]}" chmod +x "$INSTALL_DIR/et" "$INSTALL_DIR/rc" "$INSTALL_DIR/loggerx"

echo "Installing man pages to $MAN_DIR..."
"${SUDO_CMD[@]}" mkdir -p "$MAN_DIR"
"${SUDO_CMD[@]}" cp "$ET_DIR/et.1" "$MAN_DIR/et.1"
"${SUDO_CMD[@]}" cp "$RC_DIR/rc.1" "$MAN_DIR/rc.1"
"${SUDO_CMD[@]}" cp "$LOGGERX_DIR/loggerx.1" "$MAN_DIR/loggerx.1"

echo
echo "Installed successfully: et, rc, loggerx"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Warning: '$INSTALL_DIR' is not currently in your PATH."
  echo "Add it in your shell config, for example:"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

if command -v mandb >/dev/null 2>&1; then
  echo "Tip: run 'mandb' (possibly with sudo) if man pages are not immediately found."
fi
