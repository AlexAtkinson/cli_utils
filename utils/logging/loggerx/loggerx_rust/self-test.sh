#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/target/release/loggerx_rust"

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

cargo build --release --manifest-path "$SCRIPT_DIR/Cargo.toml"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOGGER_CAPTURE="$TMP_DIR/logger.capture"
touch "$LOGGER_CAPTURE"
cat > "$TMP_DIR/logger" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >> "$LOGGER_CAPTURE"
EOF
chmod +x "$TMP_DIR/logger"

help_out="$(PATH="$TMP_DIR:$PATH" "$BIN" --help)"
assert_contains "$help_out" "<LEVEL> <MESSAGE...>" "help usage"

set +e
invalid_out="$(PATH="$TMP_DIR:$PATH" "$BIN" BAD_LEVEL test 2>&1)"
invalid_rc=$?
set -e
assert_eq "1" "$invalid_rc" "invalid level exits 1"
assert_contains "$invalid_out" "Invalid log level" "invalid level message"

run_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' "$BIN" INFO hello world)"
assert_contains "$run_out" "host1 myapp[" "output includes host and app"
assert_contains "$run_out" "INFO" "output includes level"
raw_before="$(cat "$LOGGER_CAPTURE")"
assert_eq "" "$raw_before" "syslog disabled by default"

run_syslog_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' SYSLOG='true' "$BIN" INFO hello world)"
assert_contains "$run_syslog_out" "INFO" "output includes level with SYSLOG=true"
raw_syslog="$(cat "$LOGGER_CAPTURE")"
assert_contains "$raw_syslog" "myapp[" "syslog raw includes app"
assert_contains "$raw_syslog" "INFO: hello world" "syslog raw includes message"

LOG_FILE="$TMP_DIR/loggerx-rust.log"
file_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' LOG_TO_FILE='true' LOG_FILE="$LOG_FILE" SYSLOG='true' "$BIN" WARNING disk high)"
warning_count="$(grep -o 'WARNING' <<<"$file_out" | wc -l | tr -d ' ')"
assert_eq "2" "$warning_count" "LOG_TO_FILE duplicates stdout like shell"
file_content="$(cat "$LOG_FILE")"
assert_contains "$file_content" "disk high" "LOG_TO_FILE appends formatted line"

echo "All loggerx_rust self-tests passed."
