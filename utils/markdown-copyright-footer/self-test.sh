#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/md-add-copyright"

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

[[ -x "$BIN" ]] || fail "md-add-copyright missing or not executable"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/sample.md" <<'EOF'
# Title
EOF

check_out="$($BIN --check --path "$TMP_DIR" --owner "Alex Atkinson" --year 2026 || true)"
[[ "$check_out" == *"CHANGE:"* ]] || fail "check mode did not report change"
pass "check mode detects pending change"

$BIN --path "$TMP_DIR" --owner "Alex Atkinson" --year 2026 --update >/dev/null
count="$({ grep -o "Copyright © .* All Rights Reserved\." "$TMP_DIR/sample.md" || true; } | wc -l | tr -d ' ')"
assert_eq "1" "$count" "single canonical block inserted"

cat > "$TMP_DIR/dup.md" <<'EOF'
# Doc

Copyright © 2023 Someone. All Rights Reserved.

<!-- markdownlint-disable MD033 -->
<br><br>
<p align="center">
  Copyright © 2024 Someone Else. All Rights Reserved.
</p>

<!-- markdownlint-disable MD033 -->
<br><br>
<p style="text-align: center;">
</p>
EOF

run_out="$($BIN --file "$TMP_DIR/dup.md" --owner "Alex Atkinson" --year 2026 --update 2>&1 || true)"
[[ "$run_out" == *"duplicate/broken"* || "$run_out" == *"broken copyright block"* ]] || fail "duplicate/broken notice missing"
count2="$({ grep -o "Copyright © .* All Rights Reserved\." "$TMP_DIR/dup.md" || true; } | wc -l | tr -d ' ')"
assert_eq "1" "$count2" "duplicate and broken blocks consolidated"

cat > "$TMP_DIR/diff.md" <<'EOF'
# Diff

Copyright © 2020 Old Owner. All Rights Reserved.
EOF

set +e
$BIN --file "$TMP_DIR/diff.md" --owner "Alex Atkinson" --year 2026 </dev/null >/tmp/md_add_selftest.out 2>/tmp/md_add_selftest.err
rc=$?
set -e
assert_eq "2" "$rc" "non-interactive differing block requires --update"

echo "All md-add-copyright self-tests passed."
