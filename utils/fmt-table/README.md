# fmt-table

A Go utility to render aligned terminal tables and persist session state for dynamic append/update workflows.

## Goals

- Render title and content rows with aligned columns
- Persist table state across invocations
- Append rows and redraw the previously printed table snapshot in interactive terminals
- Support ASCII and Markdown table output formats

## Usage

```bash
fmt-table [options]
```

### Options

- `-t`, `--title-row` comma-separated title row
- `-r`, `--row` comma-separated content row (repeatable)
- `-w`, `--width` `dynamic`, `equal`, `full`, or integer width
- `-f`, `--frame` add frame borders
- `-e`, `--end` print closing border
- `-a`, `--append` append mode for framed output
- `-c`, `--clear-state` clear persisted state
- `-n`, `--new-session` ignore prior state for this run
- `-m`, `--markdown` use markdown output when creating a new session
- `-b1`, `--bold-first-column` compatibility flag (accepted)
- `-s`, `--screen` compatibility flag (accepted)
- `-F`, `--force` compatibility flag (accepted)
- `-h`, `--help` show help

## Examples

```bash
# Start a new framed table session
fmt-table -n -t "Task,Status" -r "Build,Running" -f

# Append a row and redraw previous snapshot in-place when interactive
fmt-table -r "Test,Queued" -fa

# Markdown session
fmt-table -n -m -t "A,B" -r "1,2"
fmt-table -r "3,4"
```

## State file

State is stored in:

`~/.cache/fmt-table/state.json`

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

## Build and test

```bash
make
make self-test
```

## Manual page

After installation:

```bash
man fmt-table
```
