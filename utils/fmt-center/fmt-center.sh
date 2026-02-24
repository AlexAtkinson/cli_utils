#!/usr/bin/env bash
set -euo pipefail

# fmt-center: center a short string on the terminal line
# Usage: fmt-center <text> [fill-char]
# If no args provided but stdin is piped, reads text from stdin.

text=""
ch=" "

if [[ $# -eq 0 ]]; then
  # If piped input is available, read it; otherwise show usage.
  if ! tty -s; then
    text="$(cat -)"
    # strip trailing newline if present
    text="${text%$'\n'}"
    # allow optional fill character via env var when reading from stdin
    ch="${FMT_CENTER_FILL:- }"
  else
    echo "Usage: fmt-center <text> [fill-char]" >&2
    exit 1
  fi
else
  text="$1"
  if [[ $# -ge 2 ]]; then
    ch="${2:0:1}"
  fi
fi

# Determine terminal width; fall back to 80 if unavailable
TERM_COLS="$(tput cols 2>/dev/null || echo 80)"
str_len=${#text}

if (( str_len >= TERM_COLS )); then
  printf "%s\n" "$text"
  exit 0
fi

filler_len=$(( (TERM_COLS - str_len) / 2 ))

# Build filler efficiently using printf; replace spaces with fill char if needed
if [[ "$ch" == " " ]]; then
  filler="$(printf '%*s' "$filler_len" '')"
else
  filler="$(printf '%*s' "$filler_len" '' | tr ' ' "$ch")"
fi

printf "%s%s%s" "$filler" "$text" "$filler"
if (( (TERM_COLS - str_len) % 2 != 0 )); then
  printf "%s" "$ch"
fi
printf "\n"
