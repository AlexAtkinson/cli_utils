#!/usr/bin/env bash
# rc
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 'rc' (result check) and 'et' (echo task) provide a simple
# and consistent method of exit code validation and logging.
#
# 'et' is used to log the start of a task.
# 'rc' validates the exit code and logs the end of the task.
#
# Arguments:
#   - $1    The exit code.
#   - $2    The expected exit code.
#   - $3    If KILL is passed then exit with passed exit
#           code.
# Usage:
#   export TASK="<task description>"; et
#   true; rc $? 0 KILL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

EXIT_CODE=$1
EXIT_DESIRED=$2

# If APP_NAME is already set in the environment, use it. Otherwise, try to infer it from the parent process.
[[ -n "$APP_NAME" ]] && APP_NAME="$APP_NAME"
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
  if [[ "$2" == "KILL" ]]; then
    # If function, then return
    if [[ "${FUNCNAME[*]:1}" != "" ]] && [[ "${FUNCNAME[-1]}" != "main" ]]; then
      return "$EXIT_CODE"
    fi
    exit "$EXIT_CODE"
  fi
fi