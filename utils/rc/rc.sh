#!/usr/bin/env bash

rc() {
  local EXIT_CODE=$?
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -x "$SCRIPT_DIR/rc" ]]; then
    RC_EXIT_CODE="$EXIT_CODE" "$SCRIPT_DIR/rc" "$@"
    return $?
  fi

  RC_EXIT_CODE="$EXIT_CODE" command rc "$@"
}
