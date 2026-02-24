#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/fmt-center"

fail() { echo "[FAIL] $1" >&2; exit 1; }
pass() { echo "[PASS] $1"; }

assert_eq() {
	local expected="$1"
	local actual="$2"
	local name="$3"
	if [[ "$expected" != "$actual" ]]; then
		echo "[FAIL] $name" >&2
		echo "--- expected ---" >&2
		printf "%s\n" "$expected" >&2
		echo "--- actual ---" >&2
		printf "%s\n" "$actual" >&2
		exit 1
	fi
	pass "$name"
}

cd "$SCRIPT_DIR"
go build -o fmt-center ./main.go

[[ -x "$BIN" ]] || fail "fmt-center binary missing"

out1="$($BIN "tukka")"
[[ "$out1" == *"tukka"* ]] || fail "expected output to contain input"
pass "simple arg center"

out2="$(echo "hello" | $BIN)"
[[ "$out2" == *"hello"* ]] || fail "stdin centering failed"
pass "stdin center"

odd_expected='...abc....'
odd_actual="$(FMT_CENTER_COLS=10 "$BIN" "abc" | tr ' ' '.')"
assert_eq "$odd_expected" "$odd_actual" "odd-width left-bias padding"

even_expected='....abc....'
even_actual="$(FMT_CENTER_COLS=11 "$BIN" "abc" | tr ' ' '.')"
assert_eq "$even_expected" "$even_actual" "even-width balanced padding"

multi_arg_expected='..hi.there..'
multi_arg_actual="$(FMT_CENTER_COLS=12 "$BIN" hi there | tr ' ' '.')"
assert_eq "$multi_arg_expected" "$multi_arg_actual" "multi-arg text join"

width_flag_expected='...abc....'
width_flag_actual="$("$BIN" --width 10 abc | tr ' ' '.')"
assert_eq "$width_flag_expected" "$width_flag_actual" "--width overrides terminal width"

width_short_expected='....abc....'
width_short_actual="$("$BIN" -w 11 abc | tr ' ' '.')"
assert_eq "$width_short_expected" "$width_short_actual" "-w short flag works"

wrap_expected=$'abcdef\n.ghi..'
wrap_actual="$("$BIN" --width 6 abcdefghi | tr ' ' '.')"
assert_eq "$wrap_expected" "$wrap_actual" "wrapped output is centered per line"

ansi_expected=$'..\e[01;33mWARNING\e[0m..'
ansi_actual="$("$BIN" --width 11 $'\e[01;33mWARNING\e[0m' | tr ' ' '.')"
assert_eq "$ansi_expected" "$ansi_actual" "ansi color codes ignored for centering width"

echo "All fmt-center self-tests passed."
