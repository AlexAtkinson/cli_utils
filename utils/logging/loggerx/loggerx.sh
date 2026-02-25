#!/usr/bin/env bash
# loggerx
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Syslog-style exit code handling with colors to improve DX.
# Notes:
#   - Enables consistent log and script output.
#   - Named loggerx to avoid clobbering logger if present.
#   - There is no 9th/SUCCESS severity in RFC5424.
#   - Output aligned with syslog.
#   - Accepts multi-line logging.
#     IE: loggerx INFO "This is a
#                       multi-line
#                       log entry"
#   - If APP_NAME is not set in the environment, it will be
#     inferred from the parent process's command line or
#     environment variables.
# Globals:
#   LOG_TO_FILE    - If set to "true", logs will be appended to LOG_FILE.
#   LOG_FILE       - The file to which logs will be appended if LOG_TO_FILE is "true".
#   APP_NAME       - The name of the application or script using loggerx. Can be set in the environment or inferred.
# Arguments:
#   - $1    Log Level
#   - $2-   Message
# Usage:
#   loggerx INFO "This is an info message"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

C_EMERGENCY='\e[01;30;41m' # EMERGENCY
C_ALERT='\e[01;31;43m'     # ALERT
C_CRITICAL='\e[01;97;41m'  # CRITICAL
C_ERROR='\e[01;31m'        # ERROR
C_WARNING='\e[01;33m'      # WARNING
C_NOTICE='\e[01;30;107m'   # NOTICE
C_INFO='\e[01;39m'         # INFO
C_DEBUG='\e[01;97;46m'     # DEBUG
C_SUCCESS='\e[01;32m'      # SUCCESS

case $1 in
  "EMERGENCY") C="C_${1}"; S=$(printf "%-39s" '') ;;
  "ALERT")     C="C_${1}"; S=$(printf "%-35s" '') ;;
  "CRITICAL")  C="C_${1}"; S=$(printf "%-38s" '') ;;
  "ERROR")     C="C_${1}"; S=$(printf "%-35s" '') ;;
  "WARNING")   C="C_${1}"; S=$(printf "%-37s" '') ;;
  "NOTICE")    C="C_${1}"; S=$(printf "%-36s" '') ;;
  "INFO")      C="C_${1}"; S=$(printf "%-34s" '') ;;
  "DEBUG")     C="C_${1}"; S=$(printf "%-35s" '') ;;
  "SUCCESS")   C="C_${1}"; S=$(printf "%-37s" '') ;;
  *)           loggerx ERROR "Invalid log level: '$1'!"
               return 1 ;;
esac

# If APP_NAME is already set in the environment, use it. Otherwise, try to infer it from the parent process.
[[ -n "$APP_NAME" ]] && APP_NAME="$APP_NAME"
[[ -z "$APP_NAME" ]] && APP_NAME="$(strings /proc/$PPID/task/$PPID/environ | grep '_=' | cut -d= -f2- | xargs basename 2>/dev/null)"
[[ -z "$APP_NAME" || "$APP_NAME" == " " ]] && APP_NAME="${0##*/}"
[[ "$APP_NAME" == "loggerx" ]] && APP_NAME="$(cat /proc/$PPID/task/$PPID/cmdline | xargs basename 2>/dev/null)"

# Set the PID of the original caller as an environment variable for potential use in log messages or other logic.
APP_PID="[$PPID] "

MSG=$(printf '%b' "$(date --utc +'%Y-%m-%dT%H-%M-%SZ') ${HOSTNAME} ${APP_NAME}${APP_PID}${!C}${1}\e[0m: $(sed 's/^ \+//g'<<<"${*:2}")")
LOG=$(sed -z 's/\n$//g'<<<"${MSG}" | sed -z "s/\n/\n${S}/g")
RAW="${APP_NAME}${APP_PID}${1}: $(sed 's/  */ /g'<<<"${*:2}")"

if [[ "$LOG_TO_FILE" == "true" ]]; then
  echo "$LOG" | tee -a "$LOG_FILE"
else
  echo "$LOG"
fi

echo "$RAW" | logger
