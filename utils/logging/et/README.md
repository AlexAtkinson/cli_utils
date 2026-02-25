# et

'et' (echo task) and 'rc' (result check) provide a simple and consistent method of exit code validation and logging.

## Behavior

- Uses task text from positional arguments, e.g. `et "Write release notes"`
- If no positional args are provided, reads task text from `$TASK`
- Emits `TASK START: <task>...` using `loggerx INFO` when available
- Falls back to plain `INFO` output if `loggerx` is not installed

## Usage

```bash
et [task words...]
```

### Options

- `-h`, `--help` show help and exit

## Examples

```bash
et "Refactor parser"
TASK="Prepare release" et
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

## Build with Make

```bash
make
```

## Manual page

After installation:

```bash
man et
```
