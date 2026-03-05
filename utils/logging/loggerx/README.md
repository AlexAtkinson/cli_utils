# loggerx

`loggerx` is a syslog-style terminal logger.

The classic/root implementation in this directory is the shell script:

- `loggerx.sh`

Additional implementations are available:

- `loggerx_golang/` (Go implementation)
- `loggerx_rust/` (Rust implementation)

Note the performance profile for each:

```bash
./benchmark.sh -t 10 -n 10000
    Finished `release` profile [optimized] target(s) in 0.01s
loggerx benchmark
iterations=10000 warmup=50 level=INFO syslog=true threads=10 cpu_threads=12 real_logger=false

impl              total_s       avg_ms    ops_per_s
------------ ------------ ------------ ------------
shell           35.779641        3.578       279.49
go              12.744090        1.274       784.68
rust            10.257245        1.026       974.92
```

## Project structure

```text
loggerx/
├── loggerx.sh              # classic/root implementation
├── loggerx_golang/         # Go implementation (main.go, self-test.sh, Makefile)
├── loggerx_rust/           # Rust implementation (Cargo project)
├── benchmark.sh            # shell vs go vs rust benchmark helper
├── install.sh
├── uninstall.sh
└── loggerx.1
```

## Usage

```bash
loggerx <LEVEL> <MESSAGE...>
```

### Levels

```text
0/EMERGENCY    3/ERROR        6/INFO
1/ALERT        4/WARNING      7/DEBUG
2/CRITICAL     5/NOTICE       9/SUCCESS
```

### Environment variables

- `APP_NAME`: optional override for inferred application name.
- `APP_PID`: optional override for inferred PID prefix (for forwarding use cases).
- `LOG_TO_FILE`: when set to `true`, also appends formatted output to `LOG_FILE`.
- `LOG_FILE`: path used when `LOG_TO_FILE=true`.

## Examples

```bash
loggerx INFO "service started"
loggerx 6 "service started"
export APP_NAME=myapp; loggerx WARNING "disk usage high"
LOG_TO_FILE=true LOG_FILE=/tmp/myapp.log loggerx ERROR "request failed"
```

## Benchmark

Run from this directory:

```bash
./benchmark.sh
```

Optional concurrency per implementation:

```bash
./benchmark.sh --threads 8
```

Notes:

- `--threads` controls worker concurrency within one implementation run.
- Benchmarks for `shell`, `go`, and `rust` always run sequentially (never at the same time) to ensure they don't clobber each other's results.
- Thread count is capped to available CPU threads. ;)

## Install

From this directory:

```bash
./install.sh
```

The installer supports implementation selection:

```bash
./install.sh --lang bash
./install.sh --lang golang
./install.sh --lang rust
```

Notes:

- If `--lang` is omitted in an interactive shell, `install.sh` prompts which implementation to install.
- In non-interactive mode, it defaults to the Go implementation.
- All variants install to the same command name: `loggerx`.

## Uninstall

From this directory:

```bash
./uninstall.sh
```

## Manual page

After installation:

```bash
man loggerx
```
