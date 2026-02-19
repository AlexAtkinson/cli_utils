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

[[ -x "$FMT_TABLE" ]] || fail "fmt-table is not executable: $FMT_TABLE"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

help_output="$($FMT_TABLE --help)"
[[ "$help_output" == *"Generate formatted tables in the terminal."* ]] || fail "help output missing description"
pass "help output"

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

ascii_title_border_expected='+----+----+
| T1 | T2 |
| V1 | V2 |'
ascii_title_border_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -n -t "T1,T2" -r "V1,V2" | cat)"
assert_eq "$ascii_title_border_expected" "$ascii_title_border_actual" "ascii title top border"

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
assert_eq "$frame_append_expected" "$frame_append_actual" "frame top border persists on append redraw"

HOME="$TMP_HOME" "$FMT_TABLE" -c >/dev/null
HOME="$TMP_HOME" "$FMT_TABLE" -t "H1,H2" -r "X,Y" >/dev/null
state_expected='+----+----+
| H1 | H2 |
| X  | Y  |
| Z  | W  |'
state_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -r "Z,W")"
assert_eq "$state_expected" "$state_actual" "state persistence reuse"

HOME="$TMP_HOME" "$FMT_TABLE" -c >/dev/null
HOME="$TMP_HOME" "$FMT_TABLE" -n -m -t "M1,M2" -r "A,B" >/dev/null
markdown_locked_expected='| M1 | M2 |
| -- | -- |
| A  | B  |
| C  | D  |'
markdown_locked_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -r "C,D")"
assert_eq "$markdown_locked_expected" "$markdown_locked_actual" "markdown session format lock"

HOME="$TMP_HOME" "$FMT_TABLE" -c >/dev/null
HOME="$TMP_HOME" "$FMT_TABLE" -n -t "S1,S2" -r "A,B" >/dev/null
ascii_locked_expected='+----+----+
| S1 | S2 |
| A  | B  |
| C  | D  |'
ascii_locked_actual="$(HOME="$TMP_HOME" "$FMT_TABLE" -m -r "C,D")"
assert_eq "$ascii_locked_expected" "$ascii_locked_actual" "ascii session format lock"

STATE_FILE="$TMP_HOME/.cache/fmt-table/state.json"
[[ -f "$STATE_FILE" ]] || fail "state file missing after sequential runs"

state_line_count="$(python3 - <<'PY' "$STATE_FILE"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
print(data.get('last_rendered_line_count', -1))
PY
)"

state_rendered_lines_len="$(python3 - <<'PY' "$STATE_FILE"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
value = data.get('last_rendered_lines', [])
print(len(value) if isinstance(value, list) else -1)
PY
)"

[[ "$state_line_count" =~ ^[0-9]+$ ]] || fail "persisted last_rendered_line_count is invalid"
[[ "$state_rendered_lines_len" =~ ^[0-9]+$ ]] || fail "persisted last_rendered_lines is invalid"
assert_eq "$state_line_count" "$state_rendered_lines_len" "persisted redraw state consistency"
pass "persisted redraw state keys"

echo "All fmt-table self-tests passed."
