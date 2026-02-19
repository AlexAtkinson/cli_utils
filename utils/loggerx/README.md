# loggerx

A colorized terminal logger implemented in Go, with optional file logging and syslog output.

## Usage

```bash
loggerx [options] LEVEL MESSAGE...
```

### Levels

`EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG SUCCESS`

### Options

- `--log-to-file` append rendered output to a log file
- `--log-file PATH` path for file logging (default: `$LOG_FILE` or `./loggerx.log`)
- `--no-color` disable ANSI color output
- `-h`, `--help` show help and exit

### Environment variables

- `LOG_TO_FILE=true|false` default for `--log-to-file`
- `LOG_FILE=/path/to/file` default for `--log-file`

## Examples

```bash
loggerx INFO "service started"
loggerx WARNING "cache miss on key user:42"
loggerx --log-to-file --log-file /tmp/app.log ERROR "request failed"
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
