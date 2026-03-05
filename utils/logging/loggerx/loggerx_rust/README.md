# loggerx_rust

Rust implementation of `loggerx` behavior.

## Build

```bash
cargo build --release
```

## Usage

```bash
./target/release/loggerx_rust <LEVEL> <MESSAGE...>
```

Levels:

```text
0/EMERGENCY    3/ERROR        6/INFO
1/ALERT        4/WARNING      7/DEBUG
2/CRITICAL     5/NOTICE       9/SUCCESS
```

Environment variables:

- `APP_NAME`
- `APP_PID`
- `LOG_TO_FILE`
- `LOG_FILE`
- `HOSTNAME`
