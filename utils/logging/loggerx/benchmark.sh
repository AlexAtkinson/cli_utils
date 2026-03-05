#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_BIN="$SCRIPT_DIR/loggerx"
SH_BIN="$SCRIPT_DIR/loggerx.sh"
RUST_MANIFEST="$SCRIPT_DIR/loggerx_rust/Cargo.toml"
RUST_BIN="$SCRIPT_DIR/loggerx_rust/target/release/loggerx_rust"

ITERATIONS=1000
WARMUP=50
LEVEL="INFO"
MESSAGE=$'benchmark message line 1\n      benchmark message line 2\nbenchmark message line 3'
BUILD=true
REAL_LOGGER=false
SYSLOG_ENABLED=true
THREADS=""

detect_cpu_threads() {
  if command -v nproc >/dev/null 2>&1; then
    nproc --all
    return
  fi
  if command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN
    return
  fi
  echo 1
}

CPU_THREADS="$(detect_cpu_threads)"
if ! [[ "$CPU_THREADS" =~ ^[0-9]+$ ]] || (( CPU_THREADS < 1 )); then
  CPU_THREADS=1
fi
THREADS="1"

usage() {
  cat <<EOF
benchmark.sh - compare loggerx shell, Go, and Rust performance

Usage:
  $(basename "$0") [options]

Options:
  -n, --iterations N   Number of timed runs per implementation (default: $ITERATIONS)
  -w, --warmup N       Number of warmup runs per implementation (default: $WARMUP)
  -l, --level LEVEL    Log level to use (default: $LEVEL)
  -m, --message TEXT   Message payload (default: multiline benchmark text)
  -t, --threads N      Worker threads per implementation (default: 1).
                       If N > 1, runs that implementation concurrently.
      --no-build       Skip building Go/Rust binaries
      --no-syslog      Disable SYSLOG during benchmark runs
      --real-logger    Use system logger instead of stubbed logger sink
  -h, --help           Show help

Notes:
  - SYSLOG is explicitly enabled by default so all implementations exercise logger path.
  - If --threads is greater than 1, concurrency is enabled for each implementation.
  - Benchmarks across languages (shell, go, rust) always run sequentially to avoid cross-impact.
  - Thread count is capped to available CPU threads.
  - By default this script stubs logger(1) so measurements focus on loggerx implementations,
    not syslog daemon I/O even when SYSLOG is enabled.
  - All implementations are invoked as separate processes for fair CLI comparison.

Examples:
  $(basename "$0") -n 5000 -w 200
  $(basename "$0") --threads 8 -n 10000
  $(basename "$0") --real-logger -n 1000
  $(basename "$0") --no-syslog -n 1000
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    -w|--warmup)
      WARMUP="$2"
      shift 2
      ;;
    -l|--level)
      LEVEL="$2"
      shift 2
      ;;
    -m|--message)
      MESSAGE="$2"
      shift 2
      ;;
    -t|--threads)
      THREADS="$2"
      shift 2
      ;;
    --no-build)
      BUILD=false
      shift
      ;;
    --no-syslog)
      SYSLOG_ENABLED=false
      shift
      ;;
    --real-logger)
      REAL_LOGGER=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || ! [[ "$WARMUP" =~ ^[0-9]+$ ]]; then
  echo "error: iterations and warmup must be non-negative integers" >&2
  exit 2
fi

if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || (( THREADS < 1 )); then
  echo "error: threads must be a positive integer" >&2
  exit 2
fi

if (( THREADS > CPU_THREADS )); then
  echo "warning: requested threads ($THREADS) exceeds CPU threads ($CPU_THREADS); capping to $CPU_THREADS" >&2
  THREADS="$CPU_THREADS"
fi

if [[ "$BUILD" == "true" ]]; then
  go build -o "$GO_BIN" "$SCRIPT_DIR/loggerx_golang/main.go"
  cargo build --release --manifest-path "$RUST_MANIFEST"
fi

if [[ ! -x "$GO_BIN" ]]; then
  echo "error: Go binary not found/executable: $GO_BIN" >&2
  exit 1
fi
if [[ ! -x "$RUST_BIN" ]]; then
  echo "error: Rust binary not found/executable: $RUST_BIN" >&2
  exit 1
fi
if [[ ! -f "$SH_BIN" ]]; then
  echo "error: shell implementation not found: $SH_BIN" >&2
  exit 1
fi

BENCH_PATH_PREFIX=""
TMP_DIR=""
if [[ "$REAL_LOGGER" == "false" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  cat > "$TMP_DIR/logger" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
  chmod +x "$TMP_DIR/logger"
  BENCH_PATH_PREFIX="$TMP_DIR:"
fi

export APP_NAME="bench"
export APP_PID="[99999] "
export HOSTNAME="bench-host"
export LOG_TO_FILE="false"
if [[ "$SYSLOG_ENABLED" == "true" ]]; then
  export SYSLOG="true"
else
  export SYSLOG="false"
fi

run_shell() {
  PATH="${BENCH_PATH_PREFIX}$PATH" "$SH_BIN" "$LEVEL" "$MESSAGE" >/dev/null
}

run_go() {
  PATH="${BENCH_PATH_PREFIX}$PATH" "$GO_BIN" "$LEVEL" "$MESSAGE" >/dev/null
}

run_rust() {
  PATH="${BENCH_PATH_PREFIX}$PATH" "$RUST_BIN" "$LEVEL" "$MESSAGE" >/dev/null
}

run_iterations() {
  local fn="$1"
  local count="$2"
  local i
  local active=0

  if (( THREADS <= 1 )); then
    for ((i=0; i<count; i++)); do
      "$fn"
    done
    return
  fi

  for ((i=0; i<count; i++)); do
    "$fn" &
    active=$((active + 1))
    if (( active >= THREADS )); then
      wait -n
      active=$((active - 1))
    fi
  done

  while (( active > 0 )); do
    wait -n
    active=$((active - 1))
  done
}

bench_one() {
  local name="$1"
  local fn="$2"
  local i
  local start_ns
  local end_ns
  local elapsed_ns
  local total_s
  local avg_ms
  local ops_s

  run_iterations "$fn" "$WARMUP"

  start_ns=$(date +%s%N)
  run_iterations "$fn" "$ITERATIONS"
  end_ns=$(date +%s%N)

  elapsed_ns=$((end_ns - start_ns))
  total_s=$(awk -v ns="$elapsed_ns" 'BEGIN { printf "%.6f", ns/1000000000 }')
  if (( ITERATIONS == 0 )); then
    avg_ms="0.000"
    ops_s="0.00"
  else
    avg_ms=$(awk -v ns="$elapsed_ns" -v n="$ITERATIONS" 'BEGIN { printf "%.3f", (ns/n)/1000000 }')
    ops_s=$(awk -v ns="$elapsed_ns" -v n="$ITERATIONS" 'BEGIN { if (ns==0) printf "inf"; else printf "%.2f", n/(ns/1000000000) }')
  fi

  printf "%-12s %12s %12s %12s\n" "$name" "$total_s" "$avg_ms" "$ops_s"
}

printf "loggerx benchmark\n"
printf "iterations=%s warmup=%s level=%s syslog=%s threads=%s cpu_threads=%s real_logger=%s\n\n" "$ITERATIONS" "$WARMUP" "$LEVEL" "$SYSLOG_ENABLED" "$THREADS" "$CPU_THREADS" "$REAL_LOGGER"
printf "%-12s %12s %12s %12s\n" "impl" "total_s" "avg_ms" "ops_per_s"
printf "%-12s %12s %12s %12s\n" "------------" "------------" "------------" "------------"
bench_one "shell" run_shell
bench_one "go" run_go
bench_one "rust" run_rust
