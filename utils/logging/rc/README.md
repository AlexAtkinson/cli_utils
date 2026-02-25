# rc

'et' (echo task) and 'rc' (result check) provide a simple and consistent method of exit code validation and logging.

## Behavior

- Compares `EXPECTED` to an `ACTUAL` exit code
- Logs `SUCCESS` when they match and `ERROR` when they differ
- Uses `loggerx` when available and falls back to plain UTC output otherwise
- If `KILL` is supplied and codes differ, exits with the actual exit code

## Usage

```bash
rc [options] EXPECTED [KILL]
```

### Options

- `-a`, `--actual` actual exit code (default: `$RC_EXIT_CODE` or `0`)
- `-t`, `--task` task text (default: `$TASK`)
- `-h`, `--help` show help and exit

## Examples

```bash
rc --actual 0 0
RC_EXIT_CODE=1 TASK="Deploy" rc 0
RC_EXIT_CODE=2 TASK="Deploy" rc 0 KILL
```

## Bash compatibility wrapper

`rc.sh` remains available as a wrapper function. It captures `$?` and calls the Go `rc` binary.

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

## Build with Make

```bash
make
```

## Manual page

After installation:

```bash
man rc
```
