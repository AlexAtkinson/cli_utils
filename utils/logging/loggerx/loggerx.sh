#!/usr/bin/env bash
# shellcheck disable=SC2034

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF

${0##*/} - syslog-style logger for improved developer experience (DX)

Writes output to stdout and sends raw messages to syslog via logger.
Supports multi-line messages and dynamic application naming.

Usage:
    ${0##*/} <LEVEL> <MESSAGE...>

Levels:
    0/EMERGENCY    3/ERROR        6/INFO
    1/ALERT        4/WARNING      7/DEBUG
    2/CRITICAL     5/NOTICE       9/SUCCESS

Environment Variables:
    APP_NAME       Optional. Overrides inferred application name in logs.
    APP_PID        Optional. Overrides inferred PID in logs (e.g., for et/rc forwarding).
    LOG_TO_FILE    If set to "true", also appends formatted output to LOG_FILE.
    LOG_FILE       Path to log file when LOG_TO_FILE is enabled.
    SYSLOG         If set to "true", sends output to syslog as well as stdout.

Examples:
    ${0##*/} INFO "Service started"
    export APP_NAME=myapp; ${0##*/} WARNING "Disk usage high"

EOF
  exit 0
fi

# Color codes for log levels
C_EMERGENCY='\e[01;30;41m'
C_ALERT='\e[01;31;43m'
C_CRITICAL='\e[01;30;48:5:208m'
C_ERROR='\e[01;31m'
C_WARNING='\e[01;33m'
C_NOTICE='\e[01;95m'
C_INFO='\e[01;39m'
C_DEBUG='\e[01;94m'
C_SUCCESS='\e[01;32m'

# Determine color and padding based on log level argument
# S is the sum of characters in the timestamp, hostname, app name, 
case $1 in
  0|"EMERGENCY")  LVL="EMERGENCY"; C="C_${LVL}" ;;
  1|"ALERT")      LVL="ALERT"    ; C="C_${LVL}" ;;
  2|"CRITICAL")   LVL="CRITICAL" ; C="C_${LVL}" ;;
  3|"ERROR")      LVL="ERROR"    ; C="C_${LVL}" ;;
  4|"WARNING")    LVL="WARNING"  ; C="C_${LVL}" ;;
  5|"NOTICE")     LVL="NOTICE"   ; C="C_${LVL}" ;;
  6|"INFO")       LVL="INFO"     ; C="C_${LVL}" ;;
  7|"DEBUG")      LVL="DEBUG"    ; C="C_${LVL}" ;;
  9|"SUCCESS")    LVL="SUCCESS"  ; C="C_${LVL}" ;;
  *)              loggerx ERROR "Invalid log level: '$1'!"
                  return 1 ;;
esac

# Use APP_NAME if available, otherwise infer from the parent process.
[[ -z "$APP_NAME" ]] && APP_NAME="$(strings /proc/$PPID/task/$PPID/environ | grep '_=' | cut -d= -f2- | xargs basename 2>/dev/null)"
[[ -z "$APP_NAME" || "$APP_NAME" == " " ]] && APP_NAME="${0##*/}"
[[ "$APP_NAME" == "loggerx" ]] && APP_NAME="$(cat /proc/$PPID/task/$PPID/cmdline | xargs basename 2>/dev/null)"

# Use APP_PID if available (e.g., et/rc forwarding), otherwise use PPID.
[[ -z "$APP_PID" ]] && APP_PID="[$PPID] "

# Padding for multi-line messages.
S="$(wc -c <<< "$(date --utc +'%Y-%m-%dT%H-%M-%SZ') ${HOSTNAME} ${APP_NAME}${APP_PID}${LVL}:")"
S=$(printf "%-${S}s" '')

# shellcheck disable=SC2001
MSG=$(printf '%b' "$(date --utc +'%Y-%m-%dT%H-%M-%SZ') ${HOSTNAME} ${APP_NAME}${APP_PID}${!C}${LVL}\e[0m: $(sed 's/^ \+//g'<<<"${*:2}")")
LOG=$(sed -z 's/\n$//g'<<<"${MSG}" | sed -z "s/\n/\n${S}/g")
# Normalize multi-line indent for syslog.
RAW="${APP_NAME}${APP_PID}${LVL}: $(sed '2,$s/^[[:blank:]]*/    /g'<<<"${*:2}")"

if [[ "$LOG_TO_FILE" == "true" ]]; then
  echo "$LOG" | tee -a "$LOG_FILE"
fi
if [[ "$SYSLOG" == "true" ]]; then
  echo "$RAW" | logger
fi

echo "$LOG"
