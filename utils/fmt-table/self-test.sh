#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FMT_TABLE="${SCRIPT_DIR}/fmt-table"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"

  if [[ "$expected" != "$actual" ]]; then
    echo "[FAIL] ${test_name}" >&2
    echo "--- expected ---" >&2
    printf "%s\n" "$expected" >&2
    echo "--- actual ---" >&2
    printf "%s\n" "$actual" >&2
    exit 1
  fi

  pass "$test_name"
}

cd "$SCRIPT_DIR"
go build -o fmt-table ./main.go

[[ -x "$FMT_TABLE" ]] || fail "fmt-table binary missing"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

help_output="$($FMT_TABLE --help)"
[[ "$help_output" == *"Generate formatted tables in the terminal."* ]] || fail "help output missing description"
pass "help output"

set +e
empty_out="$(HOME="$TMP_HOME" "$FMT_TABLE" 2>&1)"
empty_rc=$?
set -e
[[ "$empty_rc" -eq 2 ]] || fail "expected exit code 2 when no table input is provided"
[[ "$empty_out" == *"error: no table input provided"* ]] || fail "missing no-input error message"
pass "input required"

markdown_expected='| A | B |
| - | - |
| 1 | 2 |'
markdown_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -n -t "A,B" -r "1,2" -m)"
assert_eq "$markdown_expected" "$markdown_actual" "markdown output"

ascii_expected='+-------+----------+
| Name  | Role     |
+-------+----------+
| Alice | Engineer |
+-------+----------+'
ascii_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -n -t "Name,Role" -r "Alice,Engineer" -f | cat)"
assert_eq "$ascii_expected" "$ascii_actual" "ascii framed output"

HOME="$TMP_HOME" "$FMT_TABLE" -c >/dev/null
HOME="$TMP_HOME" "$FMT_TABLE" -n -t "Fruit,Color" -r "Apple,Red" -f >/dev/null
frame_append_expected='+--------+--------+
| Fruit  | Color  |
+--------+--------+
| Apple  | Red    |
+--------+--------+
| Banana | Yellow |
+--------+--------+'
frame_append_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -r "Banana,Yellow" -fa | cat)"
assert_eq "$frame_append_expected" "$frame_append_actual" "frame append redraw output"

HOME="$TMP_HOME" "$FMT_TABLE" -c >/dev/null
HOME="$TMP_HOME" "$FMT_TABLE" -n -m -t "M1,M2" -r "A,B" >/dev/null
markdown_locked_expected='| M1 | M2 |
| -- | -- |
| A  | B  |
| C  | D  |'
markdown_locked_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -r "C,D")"
assert_eq "$markdown_locked_expected" "$markdown_locked_actual" "markdown session format lock"

echo "All fmt-table self-tests passed."
