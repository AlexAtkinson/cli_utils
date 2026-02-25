#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/et"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$name (missing: $needle)"
  fi
  pass "$name"
}

go build -o "$BIN" "$SCRIPT_DIR/main.go"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/loggerx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$1: ${*:2}"
EOF
chmod +x "$TMP_DIR/loggerx"

help_out="$(PATH="$TMP_DIR:$PATH" "$BIN" --help)"
assert_contains "$help_out" "Reads TASK from environment" "help documents TASK env behavior"

unset_out="$(PATH="$TMP_DIR:$PATH" TASK='' "$BIN")"
assert_contains "$unset_out" "WARNING: 'TASK' not set. 'TASK' must be exported." "warns when TASK unset"
assert_contains "$unset_out" "INFO: TASK START: UNSET TASK..." "uses UNSET TASK fallback"

set_out="$(PATH="$TMP_DIR:$PATH" TASK='Deploy release' "$BIN")"
assert_contains "$set_out" "INFO: TASK START: Deploy release..." "logs TASK START with env TASK"

echo "All et self-tests passed."
