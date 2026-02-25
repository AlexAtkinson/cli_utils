#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
${0##*/} - syslog-style logger for better DX

Usage:
  ${0##*/} <LEVEL> <MESSAGE...>

Levels:
  EMERGENCY | ALERT | CRITICAL | ERROR | WARNING | NOTICE | INFO | DEBUG | SUCCESS

Behavior:
  - Writes colored output to stdout.
  - Sends raw message to syslog via logger.
  - Accepts multi-line messages.
  - Uses APP_NAME from environment when set; otherwise infers caller name.
  - If LOG_TO_FILE=true, also appends formatted output to LOG_FILE.

Examples:
  ${0##*/} INFO "Service started"
  export APP_NAME=myapp; ${0##*/} WARNING "Disk usage high"
EOF
  exit 0
fi

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
[[ -z "$APP_NAME" ]] && APP_NAME="$(strings /proc/$PPID/task/$PPID/environ | grep '_=' | cut -d= -f2- | xargs basename 2>/dev/null)"
[[ -z "$APP_NAME" || "$APP_NAME" == " " ]] && APP_NAME="${0##*/}"
[[ "$APP_NAME" == "loggerx" ]] && APP_NAME="$(cat /proc/$PPID/task/$PPID/cmdline | xargs basename 2>/dev/null)"

# Set the PID of the original caller as an environment variable for potential use in log messages or other logic.
APP_PID="[$PPID] "

# shellcheck disable=SC2001
MSG=$(printf '%b' "$(date --utc +'%Y-%m-%dT%H-%M-%SZ') ${HOSTNAME} ${APP_NAME}${APP_PID}${!C}${1}\e[0m: $(sed 's/^ \+//g'<<<"${*:2}")")
LOG=$(sed -z 's/\n$//g'<<<"${MSG}" | sed -z "s/\n/\n${S}/g")
# shellcheck disable=SC2001
RAW="${APP_NAME}${APP_PID}${1}: $(sed 's/  */ /g'<<<"${*:2}")"

if [[ "$LOG_TO_FILE" == "true" ]]; then
  echo "$LOG" | tee -a "$LOG_FILE"
else
  echo "$LOG"
fi

echo "$RAW" | logger
