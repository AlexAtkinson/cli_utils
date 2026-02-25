#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
${0##*/} - validate exit code and log task end via loggerx

NOTE: This departs from legacy 'rc', now requiring a minimum of two arguments.

Usage:
  ${0##*/} <exit_code> <expected_code> [KILL]

Arguments:
  exit_code      Actual exit code to evaluate. Will always be '\$?'.
  expected_code  Expected exit code.
  KILL           Optional. Terminate program on error.

Behavior:
  - Reads TASK from environment.
  - Logs SUCCESS on match, ERROR on mismatch.
  - If TASK is unset, logs a warning and uses "UNSET TASK".

Examples:
  export TASK="Run tests"
  false; ${0##*/} $? 0 KILL
EOF
  exit 0
fi

EXIT_CODE=$1
EXIT_DESIRED=$2

# If APP_NAME is already set in the environment, use it. Otherwise, try to infer it from the parent process.
[[ -z "$APP_NAME" ]] && APP_NAME="$(strings /proc/$PPID/task/$PPID/environ | grep '_=' | cut -d= -f2- | xargs basename 2>/dev/null)"
[[ -z "$APP_NAME" || "$APP_NAME" == " " ]] && APP_NAME="${0##*/}"
[[ "$APP_NAME" == "loggerx" ]] && APP_NAME="$(cat /proc/$PPID/task/$PPID/cmdline | xargs basename 2>/dev/null)"
export APP_NAME

# If TASK is not set, WARN with a hint to export TASK from calling scripts.
[[ -z "$TASK" ]] && loggerx WARNING "'TASK' not set. 'TASK' must be exported."
[[ -z "$TASK" ]] && TASK="UNSET TASK"

if [[ "$EXIT_DESIRED" -eq "$EXIT_CODE" ]] ; then
  loggerx SUCCESS "TASK END: $TASK."
else
  loggerx ERROR "TASK END: ${TASK}. (exit code: ${EXIT_CODE}, expected: ${EXIT_DESIRED})"
  if [[ "$3" == "KILL" ]]; then
    # If function, then return
    if [[ "${FUNCNAME[*]:1}" != "" ]] && [[ "${FUNCNAME[-1]}" != "main" ]]; then
      return "$EXIT_CODE"
    fi
    exit "$EXIT_CODE"
  fi
fi