# loggerx

A colorized terminal logger implemented in Go, with syslog output.

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

## Install

From this directory:

```bash
chmod +x install.sh
./install.sh
```

## Uninstall

From this directory:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Manual page

After installation:

```bash
man loggerx
```
