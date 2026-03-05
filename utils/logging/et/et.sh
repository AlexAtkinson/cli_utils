#!/usr/bin/env bash
# et
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 'et' (echo task) and 'rc' (result check) provide a simple
# and consistent method of exit code validation and logging.
#
# 'et' is used to log the start of a task.
# 'rc' validates the exit code and logs the end of the task.
#
# Usage:
#   export TASK="<task description>"; et
#   true; rc $? 0 KILL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	cat <<EOF
${0##*/} - log task start via loggerx

Usage:
	et.sh

Behavior:
	- Reads TASK from environment.
	- Logs: TASK START: <TASK>...
	- If TASK is unset, logs a warning and uses "UNSET TASK".

Examples:
	export TASK="Deploy release"; ${0##*/}
EOF
	exit 0
fi

# If APP_NAME is already set in the environment, use it. Otherwise, try to infer it from the parent process.
[[ -z "$APP_NAME" ]] && APP_NAME="$(strings /proc/$PPID/task/$PPID/environ | grep '_=' | cut -d= -f2- | xargs basename 2>/dev/null)"
[[ -z "$APP_NAME" || "$APP_NAME" == " " ]] && APP_NAME="${0##*/}"
[[ "$APP_NAME" == "loggerx" ]] && APP_NAME="$(cat /proc/$PPID/task/$PPID/cmdline | xargs basename 2>/dev/null)"
export APP_NAME

# Set the PID of the original caller as an environment variable for potential use in log messages or other logic.
APP_PID="[$PPID] "
export APP_PID

# If TASK is not set, WARN with a hint to export TASK from calling scripts.
[[ -z "$TASK" ]] && loggerx WARNING "'TASK' not set. 'TASK' must be exported."
[[ -z "$TASK" ]] && TASK="UNSET TASK"

loggerx INFO "TASK START: $TASK..."
