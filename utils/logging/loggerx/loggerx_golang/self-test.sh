#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/loggerx"

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

assert_not_empty() {
  local value="$1"
  local name="$2"
  if [[ -z "$value" ]]; then
    fail "$name (value is empty)"
  fi
  pass "$name"
}

count_leading_spaces() {
  local value="$1"
  awk '{ match($0, /^ */); print RLENGTH; }' <<<"$value"
}

go build -o "$BIN" "$SCRIPT_DIR/main.go"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOGGER_CAPTURE="$TMP_DIR/logger.capture"
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

run_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' SYSLOG='true' "$BIN" INFO hello world)"
assert_contains "$run_out" "host1 myapp[" "output includes host and app"
assert_contains "$run_out" "INFO" "output includes level"
assert_contains "$run_out" "hello world" "output includes message"
raw_syslog="$(cat "$LOGGER_CAPTURE")"
assert_contains "$raw_syslog" "myapp[" "syslog raw includes app"
assert_contains "$raw_syslog" "INFO: hello world" "syslog raw includes message"

no_syslog_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' "$BIN" INFO no syslog)"
assert_contains "$no_syslog_out" "no syslog" "stdout works without SYSLOG"
raw_after_no_syslog="$(cat "$LOGGER_CAPTURE")"
assert_eq "$raw_syslog" "$raw_after_no_syslog" "syslog disabled unless SYSLOG=true"

numeric_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' SYSLOG='true' "$BIN" 6 numeric test)"
assert_contains "$numeric_out" "INFO" "numeric level maps to INFO"

custom_pid_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' APP_PID='(pid42) ' HOSTNAME='host1' SYSLOG='true' "$BIN" WARNING custom pid)"
assert_contains "$custom_pid_out" "myapp(pid42)" "APP_PID passthrough in rendered output"

fallback_host_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='' SYSLOG='true' "$BIN" INFO host fallback)"
fallback_host="$(awk '{print $2}' <<<"$fallback_host_out")"
assert_not_empty "$fallback_host" "hostname fallback when HOSTNAME unset"

multiline_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' SYSLOG='true' "$BIN" INFO $'FOO\n      BAR')"
multiline_plain="$(sed -r 's/\x1B\[[0-9;:]*[A-Za-z]//g' <<<"$multiline_out")"
multiline_line1="$(head -n1 <<<"$multiline_plain")"
multiline_line2="$(sed -n '2p' <<<"$multiline_plain")"
prefix_before_foo="${multiline_line1%FOO}"
expected_indent=${#prefix_before_foo}
actual_indent="$(count_leading_spaces "$multiline_line2")"
assert_eq "$expected_indent" "$actual_indent" "multiline indent aligns to message column"

raw_syslog_multiline="$(cat "$LOGGER_CAPTURE")"
assert_contains "$raw_syslog_multiline" $'INFO: FOO\n    BAR' "syslog multiline normalizes continuation indent"

LOG_FILE="$TMP_DIR/loggerx.log"
file_out="$(PATH="$TMP_DIR:$PATH" LOGGER_CAPTURE="$LOGGER_CAPTURE" APP_NAME='myapp' HOSTNAME='host1' LOG_TO_FILE='true' LOG_FILE="$LOG_FILE" SYSLOG='true' "$BIN" WARNING disk high)"
assert_contains "$file_out" "WARNING" "stdout still prints with LOG_TO_FILE"
warning_count="$(grep -o 'WARNING' <<<"$file_out" | wc -l | tr -d ' ')"
assert_eq "2" "$warning_count" "LOG_TO_FILE duplicates stdout like shell"
file_content="$(cat "$LOG_FILE")"
assert_contains "$file_content" "disk high" "LOG_TO_FILE appends formatted line"

echo "All loggerx self-tests passed."
