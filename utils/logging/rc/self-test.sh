#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/rc"

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

assert_eq() {
  local expected="$1"
  local actual="$2"
  local name="$3"
  if [[ "$expected" != "$actual" ]]; then
    fail "$name (expected=$expected actual=$actual)"
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
assert_contains "$help_out" "<exit_code> <expected_code> [KILL]" "help documents positional args"

set +e
missing_out="$(PATH="$TMP_DIR:$PATH" "$BIN" 2>&1)"
missing_rc=$?
set -e
assert_eq "2" "$missing_rc" "missing args exits 2"
assert_contains "$missing_out" "error: missing required arguments" "missing args message"

match_out="$(PATH="$TMP_DIR:$PATH" TASK='Run tests' "$BIN" 0 0)"
assert_contains "$match_out" "SUCCESS: TASK END: Run tests." "success logs TASK END"

set +e
mismatch_out="$(PATH="$TMP_DIR:$PATH" TASK='Run tests' "$BIN" 1 0 2>&1)"
mismatch_rc=$?
set -e
assert_eq "0" "$mismatch_rc" "mismatch without KILL returns 0"
assert_contains "$mismatch_out" "ERROR: TASK END: Run tests. (exit code: 1, expected: 0)" "mismatch message format"

set +e
kill_out="$(PATH="$TMP_DIR:$PATH" TASK='Run tests' "$BIN" 2 0 KILL 2>&1)"
kill_rc=$?
set -e
assert_eq "2" "$kill_rc" "KILL exits with actual code"
assert_contains "$kill_out" "ERROR: TASK END: Run tests. (exit code: 2, expected: 0)" "KILL path logs mismatch"

unset_out="$(PATH="$TMP_DIR:$PATH" TASK='' "$BIN" 0 0)"
assert_contains "$unset_out" "WARNING: 'TASK' not set. 'TASK' must be exported." "warns when TASK unset"
assert_contains "$unset_out" "SUCCESS: TASK END: UNSET TASK." "uses UNSET TASK fallback"

echo "All rc self-tests passed."
