# fmt-table

A Go utility to render aligned markdown-style terminal tables and persist session state for append/update workflows.

## Goals

- Render title and content rows with aligned columns
- Persist table state across invocations
- Append rows and redraw the previously printed table snapshot in interactive terminals
- Render markdown-style separators with terminal-bold title cells

## Usage

```bash
fmt-table [options]
```

### Options

- `-t`, `--title-row` comma-separated title row
- `-r`, `--row` comma-separated content row (repeatable)
- `-w`, `--width` `dynamic`, `equal`, `full`, or integer width
- `-A`, `--align` comma-separated column alignment list using `left`, `center`, `right`, or the short forms `l`, `c`, `r`
- `-f`, `--frame` compatibility flag (accepted; markdown-only output)
- `-e`, `--end` compatibility flag (accepted; markdown-only output)
- `-a`, `--append` append mode (compatibility behavior)
- `-c`, `--clear-state` clear persisted state
- `-n`, `--new-session` ignore prior state for this run
- `-m`, `--markdown` compatibility flag (accepted; markdown-only output)
- `-b1`, `--bold-first-column` compatibility flag (accepted)
- `-s`, `--screen` compatibility flag (accepted)
- `-F`, `--force` compatibility flag (accepted)
- `-h`, `--help` show help

## Examples

```bash
# Start a new table session (markdown-style output)
fmt-table -n -t "Task,Status" -r "Build,Running"

# Append a row and redraw previous snapshot in-place when interactive
fmt-table -r "Test,Queued"

# Markdown session (default)
fmt-table -n -m -t "A,B" -r "1,2"
fmt-table -r "3,4"

# Right-align a numeric column
fmt-table -n -t "Item,Count" -r "Apples,12" -r "Pears,3" -A "l,r"
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

## Releases

Merged pull requests that touch this directory publish a scoped GitHub Release for `fmt-table`, including Linux, macOS, and Windows amd64 archives.
Releases are generated only from merged pull requests into `main`.
