#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin"
DEFAULT_MAN_DIR="/usr/local/share/man/man1"
LOCAL_MAN_DIR="$HOME/.local/share/man/man1"
GLOBAL_INSTALL=false
INTERACTIVE=false
INSTALL_LANG=""

if [[ "$-" =~ i || -t 0 ]]; then
  INTERACTIVE=true
fi

usage() {
  echo "Usage: ${0##*/} [--global] [--lang bash|golang|rust]"
  echo
  echo "  --global          Use global defaults (/usr/local/bin and /usr/local/share/man/man1)"
  echo "  --lang <value>    Select implementation to install (bash, golang, rust)"
}

normalize_lang() {
  case "$1" in
    bash|shell|sh|classic) echo "shell" ;;
    go|golang) echo "golang" ;;
    rust|rs) echo "rust" ;;
    *) return 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      GLOBAL_INSTALL=true
      shift
      ;;
    --lang)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --lang requires a value." >&2
        usage >&2
        exit 2
      fi
      if ! INSTALL_LANG="$(normalize_lang "$2")"; then
        echo "Error: invalid --lang value '$2'. Expected bash, golang, or rust." >&2
        exit 2
      fi
      shift 2
      ;;
    --lang=*)
      if ! INSTALL_LANG="$(normalize_lang "${1#*=}")"; then
        echo "Error: invalid --lang value '${1#*=}'. Expected bash, golang, or rust." >&2
        exit 2
      fi
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      echo "Try: ${0##*/} --help" >&2
      exit 2
      ;;
  esac
done

echo "This script installs the 'loggerx' utility and its man page."
echo

if [[ -z "$INSTALL_LANG" ]]; then
  if [[ "$INTERACTIVE" == "true" ]]; then
    echo "Select loggerx implementation to install:"
    echo "  1) bash (classic loggerx.sh)"
    echo "  2) golang"
    echo "  3) rust"
    read -r -p "Choice [1/2/3] (default: 1): " USER_LANG_CHOICE
    case "${USER_LANG_CHOICE:-1}" in
      1) INSTALL_LANG="bash" ;;
      2) INSTALL_LANG="golang" ;;
      3) INSTALL_LANG="rust" ;;
      *)
        echo "Error: invalid selection '${USER_LANG_CHOICE}'." >&2
        exit 2
        ;;
    esac
  else
    INSTALL_LANG="golang"
  fi
fi

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
  read -r -p "Install binary to (default: $DEFAULT_INSTALL_DIR): " USER_INSTALL_DIR
  INSTALL_DIR="${USER_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

  read -r -p "Install man page to (default: $DEFAULT_MAN_DIR): " USER_MAN_DIR
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
cd "$SCRIPT_DIR"

case "$INSTALL_LANG" in
  bash)
    echo "Preparing loggerx (bash/classic)..."
    INSTALL_SOURCE="$SCRIPT_DIR/loggerx.sh"
    ;;
  golang)
    echo "Building loggerx (golang)..."
    go build -o loggerx ./loggerx_golang/main.go
    INSTALL_SOURCE="$SCRIPT_DIR/loggerx"
    ;;
  rust)
    if ! command -v cargo >/dev/null 2>&1; then
      echo "Error: cargo is required to build the rust implementation." >&2
      exit 1
    fi
    echo "Building loggerx (rust)..."
    cargo build --release --manifest-path "$SCRIPT_DIR/loggerx_rust/Cargo.toml"
    INSTALL_SOURCE="$SCRIPT_DIR/loggerx_rust/target/release/loggerx_rust"
    ;;
  *)
    echo "Error: unsupported install language '$INSTALL_LANG'." >&2
    exit 2
    ;;
esac

if [[ ! -f "$INSTALL_SOURCE" ]]; then
  echo "Error: expected install source not found: $INSTALL_SOURCE" >&2
  exit 1
fi

echo "Installing binary to $INSTALL_DIR..."
"${SUDO_CMD[@]}" mkdir -p "$INSTALL_DIR"
"${SUDO_CMD[@]}" cp "$INSTALL_SOURCE" "$INSTALL_DIR/loggerx"
"${SUDO_CMD[@]}" chmod +x "$INSTALL_DIR/loggerx"

echo "Installing man page to $MAN_DIR..."
"${SUDO_CMD[@]}" mkdir -p "$MAN_DIR"
"${SUDO_CMD[@]}" cp loggerx.1 "$MAN_DIR/loggerx.1"

echo
echo "loggerx installed successfully (implementation: $INSTALL_LANG)."

if [[ "$GLOBAL_INSTALL" == "true" && "$INTERACTIVE" == "true" ]]; then
  LOCAL_BIN_PATH="$LOCAL_BIN_DIR/loggerx"
  LOCAL_MAN_PATH="$LOCAL_MAN_DIR/loggerx.1"

  if [[ -e "$LOCAL_BIN_PATH" || -e "$LOCAL_MAN_PATH" ]]; then
    echo
    echo "A user-local loggerx installation was detected:"
    [[ -e "$LOCAL_BIN_PATH" ]] && echo "  - $LOCAL_BIN_PATH"
    [[ -e "$LOCAL_MAN_PATH" ]] && echo "  - $LOCAL_MAN_PATH"
    read -r -p "Remove user-local installation files now? [y/N]: " REMOVE_LOCAL_INSTALL
    if [[ "$REMOVE_LOCAL_INSTALL" =~ ^([yY]|[yY][eE][sS])$ ]]; then
      rm -f "$LOCAL_BIN_PATH" "$LOCAL_MAN_PATH"
      echo "Removed user-local loggerx installation files."
      echo "Refresh your shell command lookup/path to pick up the global install (for example: export PATH=\"\$PATH\")."
    fi
  fi
fi

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Warning: '$INSTALL_DIR' is not currently in your PATH."
  echo "Add it in your shell config, for example:"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

if command -v mandb >/dev/null 2>&1; then
  echo "Tip: run 'mandb' (possibly with sudo) if 'man loggerx' is not immediately found."
fi
